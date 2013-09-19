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

#import <XCTest/XCTest.h>
#import "ANTDatabaseMigrationBuilder.h"

@interface ANTDatabaseMigrationBuilderTests : XCTestCase @end

@implementation ANTDatabaseMigrationBuilderTests {
    PLSqliteDatabase *_db;
}

- (void) setUp {
    _db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    [_db open];
}

- (void) tearDown {
    _db = nil;
}

- (void) testDSL {
    ANTDatabaseMigrationBuilder *migration = [ANTDatabaseMigrationBuilder new];
    
    migration.migration(1, ^(ANTDatabaseMigrationState *state) {
        state.update(
            @"CREATE TABLE radar ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                "open_radar INTEGER NOT NULL CHECK (open_radar == 0 OR open_radar == 1),"
                "radar_number INTEGER NOT NULL,"
                "unread INTEGER NOT NULL CHECK (unread == 0 OR unread == 1),"
                "CONSTRAINT radar_unique_number UNIQUE (open_radar, radar_number)"
            ");"
        );
        state.update(@"CREATE INDEX radar_number_idx ON radar (radar_number);");
    });

    migration.migration(2, ^(ANTDatabaseMigrationState *state) {
        state.update(@"INSERT INTO radar (open_radar, radar_number, unread) VALUES ( ?, ?, ? );", @(0), @(1000), @(1));
    });

    /* Perform database migrations. We run them twice to validate that we're not re-running a migration. */
    NSError *error;
    PLSqliteMigrationManager *vmgr = [PLSqliteMigrationManager new];
    PLDatabaseMigrationManager *manager = [[PLDatabaseMigrationManager alloc] initWithTransactionManager: vmgr
                                                                                            versionManager: vmgr
                                                                                                  delegate: migration];
    
    XCTAssertTrue([manager migrateDatabase: _db error: &error], @"Failed to migrate database: %@", error);
    XCTAssertTrue([manager migrateDatabase: _db error: &error], @"Failed to migrate database (after migrating once already): %@", error);

    /* Verify that the changes were applied */
    XCTAssertTrue([_db tableExists: @"radar"], @"Table was not created");
    
    __block BOOL found = NO;
    [[_db executeQuery: @"SELECT radar_number FROM radar"] enumerateWithBlock: ^(id <PLResultSet> rs, BOOL *stop) {
        XCTAssertFalse(found, @"INSERT migration was run more than once -- more than one result was found");
        
        XCTAssertEqual([rs intForColumnIndex: 0], (int32_t) 1000, @"INSERT migration did not run");
        found = YES;
    }];
    
    XCTAssertTrue(found, @"INSERT migration did not run");


}

@end