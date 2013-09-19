/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "ANTLocalRadarDatabase.h"

#import <PLFoundation/PLFoundation.h>
#import <PlausibleDatabase/PlausibleDatabase.h>

#import "ANTDatabaseMigrationBuilder.h"

/**
 * @internal
 *
 * Manages persistent state for the ANTLocalRadarCache
 *
 * @par Thread Safety
 *
 * Thread-safe. May be used from any thread.
 */
@implementation ANTLocalRadarDatabase {
@private
    /** Backing database connection provider */
    id<PLDatabaseConnectionProvider> _connectionPool;
}


/**
 * Initialize with an SQLite connection provider.
 *
 * @param connectionProvider A connection provider to be used to store local Radar data. Must return
 * instances of PLSqliteDatabase.
 */
- (id) initWithConnectionProvider: (id<PLDatabaseConnectionProvider>) connectionProvider {
    PLSuperInit();
    
    
    /* Insert a connection filter to perform one-time database connection configuration. */
    PLDatabaseFilterConnectionProvider *filterProvider = [[PLDatabaseFilterConnectionProvider alloc] initWithConnectionProvider: connectionProvider filterBlock:^(id<PLDatabase> db) {
        NSError *error;
        
        /* Set the persistent journal mode to WAL; this provides us with improved concurrency and performance.
         * While this setting is on-disk persisted, it must be set outside of a transaction, which precludes enabling it within a migration. */
        if (![db executeUpdateAndReturnError: &error statement: @"PRAGMA journal_mode = WAL"])
            NSLog(@"Failed to enable WAL journaling: %@", error);
        
        /* Enable foreign key constraints; these default to OFF, and the setting is not persistent across connections. */
        if (![db executeUpdateAndReturnError: &error statement: @"PRAGMA foreign_keys = ON"])
            NSLog(@"Failed to enable foreign key support: %@", error);
    }];

    /* Configure our migrations */
    ANTDatabaseMigrationBuilder *migrations = [ANTDatabaseMigrationBuilder new];
    migrations.migration(1, ^(ANTDatabaseMigrationState *state) {
        state.update(
            @"CREATE TABLE radar ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                "open_radar INTEGER NOT NULL CHECK (open_radar == 0 OR open_radar == 1),"
                "radar_number INTEGER NOT NULL,"
                "last_read_date DATETIME NOT NULL DEFAULT (strftime('%s','now'))" // The last read comment's date (as a UNIX timestamp).
                "CONSTRAINT radar_unique_number UNIQUE (open_radar, radar_number)"
            ");"
        );
        state.update(@"CREATE INDEX radar_number_idx ON radar (radar_number);");
    });
    
    PLSqliteMigrationManager *sqliteMigrationManager = [PLSqliteMigrationManager new];
    PLDatabaseMigrationManager *migrationManager = [[PLDatabaseMigrationManager alloc] initWithTransactionManager: sqliteMigrationManager
                                                                                                   versionManager: sqliteMigrationManager
                                                                                                         delegate: migrations];

    /* Insert a migration provider */
    PLDatabaseMigrationConnectionProvider *migrateProvider = [[PLDatabaseMigrationConnectionProvider alloc] initWithConnectionProvider: filterProvider
                                                                                                                      migrationManager: migrationManager];

    
    /*
     * Insert a connection pool. This will pool connections for which migrations and one-time setup has already been completed.
     * We set an unlimited capacity; in reality, capacity will be bounded by the maximum number of concurrent threads that access
     * the pool.
     */
    _connectionPool = [[PLDatabasePoolConnectionProvider alloc] initWithConnectionProvider: migrateProvider capacity: 0];

    return self;
}

/**
 * Return the latest comment date that has been read for @a radarNumber. If no comments for the given Radar
 * have previously been read, the @a date value will be nil.
 *
 * @param date On return, the latest comment date that has been read for @a radarNumber, or nil if the Radar has not been previously read.
 * @param radarNumber The radar number to look up.
 * @param openRadar YES if this is an Open Radar entry.
 * @param outError On error, will contain an error in the PLDatabaseErrorDomain.
 *
 * @return Returns YES if the database query completed successfully, NO if a database error has occured.
 */
- (BOOL) latestReadCommentDate: (NSDate **) date forRadarNumber: (NSNumber *) radarNumber openRadar: (BOOL) openRadar error: (NSError **) outError {
    PLSqliteDatabase *db = [_connectionPool getConnectionAndReturnError: outError];
    if (db == nil)
        return NO;
    
    __block BOOL result = NO;
    BOOL txSuccess = [db performTransactionWithRetryBlock: ^PLDatabaseTransactionResult {
        /* Check for an existing entry */
        NSString *query = @"SELECT radar.last_read_date FROM radar WHERE radar.radar_number = ? AND open_radar = ?";
        
        id<PLResultSet> rs = [db executeQueryAndReturnError: outError statement: query, radarNumber, @(openRadar)];
        if (rs == NULL)
            return PLDatabaseTransactionRollback;
        
        switch ([rs nextAndReturnError: outError]) {
            case PLResultSetStatusError:
                /* Query failed */
                result = NO;
                break;
                
            case PLResultSetStatusDone:
                /* No match found -- note that the query completed */
                result = YES;
                break;
                
            case PLResultSetStatusRow:
                result = YES;
                *date = [rs dateForColumnIndex: 0];
                break;
        }

        /* Clean up. This was a read-only transaction, so we can roll back */
        [rs close];
        return PLDatabaseTransactionRollback;
    } error: outError];
    
    if (!txSuccess)
        return NO;

    return result;
}

/**
 * Update the last comment read market for @a radarNumber. If no comments for the given Radar
 * have previously been read, the @a date value will be nil.
 *
 * @param date On return, the latest comment date that has been read for @a radarNumber, or nil if the Radar has not been previously read.
 * @param radarNumber The radar number to look up
 * @param outError On error, will contain an error in the PLDatabaseErrorDomain.
 *
 * @return Returns YES if the database query completed successfully, NO if a database error has occured.
 */
- (BOOL) setReadCommentDate: (NSDate *) date forRadarNumber: (NSNumber *) radarNumber openRadar: (BOOL) openRadar error: (NSError **) outError {
    PLSqliteDatabase *db = [_connectionPool getConnectionAndReturnError: outError];
    if (db == nil)
        return NO;
    
    __block BOOL result = NO;
    BOOL txSuccess = [db performTransactionWithRetryBlock: ^PLDatabaseTransactionResult {
        /* Speculatively try to update an existing entry */
        if (![db executeUpdateAndReturnError: outError statement: @"UPDATE radar SET last_read_date = ? WHERE radar_number = ? AND open_radar = ?", date, radarNumber, @(openRadar)])
            return PLDatabaseTransactionRollback;
        
        /* If no existing entry, INSERT */
        if ([db lastModifiedRowCount] == 0) {
            if (![db executeUpdateAndReturnError: outError statement: @"INSERT INTO radar (radar_number, open_radar, last_read_date) values (?, ?, ?)", radarNumber, @(openRadar), date])
                return PLDatabaseTransactionRollback;
        }

        /* Mark as complete and commit */
        result = YES;
        return PLDatabaseTransactionCommit;
    } error: outError];
    
    if (!txSuccess)
        return NO;
    
    return result;
}

@end
