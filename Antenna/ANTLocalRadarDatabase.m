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
    
    /* Configure our migrations */
    ANTDatabaseMigrationBuilder *migrations = [ANTDatabaseMigrationBuilder new];
    migrations.migration(1, ^(ANTDatabaseMigrationState *state) {
        state.update(
            @"CREATE TABLE radar ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                "open_radar INTEGER NOT NULL CHECK (open_radar == 0 OR open_radar == 1),"
                "radar_number INTEGER NOT NULL,"
                "CONSTRAINT radar_unique_number UNIQUE (open_radar, radar_number)"
            ");"
        );
        
        state.update(
            @"CREATE TABLE radar_bookmarks ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                "radar_id INTEGER NOT NULL REFERENCES radar (id),"
                "unread INTEGER NOT NULL CHECK (unread == 0 OR unread == 1),"
            ");"
        );
        state.update(@"CREATE INDEX radar_number_idx ON radar (radar_number);");
    });
    
    /* Insert a connection filter to perform one-time database connection configuration prior
     * to the connection being placed in a connection pool */
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
    
    /*
     * Insert a connection pool. This will pool connections for which migrations and one-time setup has already been completed.
     * We set an unlimited capacity; in reality, capacity will be bounded by the maximum number of concurrent threads that access
     * the pool.
     */
    _connectionPool = [[PLDatabasePoolConnectionProvider alloc] initWithConnectionProvider: filterProvider capacity: 0];

    return self;
}


@end
