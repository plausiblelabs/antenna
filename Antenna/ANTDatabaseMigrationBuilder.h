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

#import <Foundation/Foundation.h>
#import <PlausibleDatabase/PlausibleDatabase.h>

@interface ANTDatabaseMigrationState : NSObject

- (void) executeUpdate: (NSString *) statement args: (va_list) args;
- (void) executeUpdate: (NSString *) statement, ...;

/**
 * Returns a block that may be used to execute an UPDATE statement for the migration.
 *
 * The statement will be executed within the context of the migration's transaction handling.
 *
 * Calling the returned block is equivalent to the -[ANDatabaseMigrationState addUpdateStatement:] method.
 */
@property(nonatomic, readonly) void (^update)(NSString *stmt, ...);

@end

@interface ANTDatabaseMigrationBuilder : NSObject <PLDatabaseMigrationDelegate>

- (void) addMigrationWithVersion: (NSUInteger) version action: (void (^)(ANTDatabaseMigrationState *state)) action;

/**
 * Returns a block that may be used to register a migration with the given version and action.
 *
 * If a migration for the given version has already been registered, it will be replaced.
 *
 * Calling the returned block is equivalent to the -[ANTDatabaseMigration version:action:] method.
 */
@property(nonatomic, readonly) void (^migration)(NSUInteger version, void (^action)(ANTDatabaseMigrationState *state));

@end
