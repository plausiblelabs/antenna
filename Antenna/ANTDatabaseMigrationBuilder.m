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


#import "ANTDatabaseMigrationBuilder.h"

typedef BOOL (^migration_block_t)(id<PLDatabase> db, NSError **outError);
typedef BOOL (^migration_action_t)(ANTDatabaseMigrationState *);

@interface ANTDatabaseMigrationState ()

/** Any error that occured in the migration */
@property(nonatomic, readonly) NSError *error;

@end

/**
 * A single migration state associated with a ANTDatabaseMigration instance.
 */
@implementation ANTDatabaseMigrationState {
@private
    /** Backing database connection to be used for all operations. */
    id<PLDatabase> _db;

    /** Ordered array of migration_block_t blocks to be executed */
    NSError *_error;
}

/**
 * @internal
 *
 * Initialize a new migration state instance.
 */
- (instancetype) initWithDatabase: (id<PLDatabase>) database {
    if ((self = [super init]) == nil)
        return nil;

    _db = database;

    return self;
}

/**
 * Register an UPDATE statement for the migration.
 *
 * The statement will be executed within the context of the migration's transaction handling.
 *
 * @param stmt The statement to execute. Any additional parameters will be handled via standard PLDatabase parameter interpolation.
 * @param args The update parameters.
 */
- (void) executeUpdate: (NSString *) statement args: (va_list) args {
    NSError *error;
    
    /* Terminate immediately on error */
    if (_error != nil)
        return;

    /* Parse the statement */
    id<PLPreparedStatement> stmt = [_db prepareStatement: statement error: &error];
    if (stmt == nil) {
        _error = error;
        return;
    }
    
    /* Bind the parameters */
    int paramCount = [stmt parameterCount];
    if (paramCount > 0) {
        NSMutableArray *params = [NSMutableArray arrayWithCapacity: [stmt parameterCount]];
        for (int i = 0; i < paramCount; i++)
            [params addObject: va_arg(args, id)];
        [stmt bindParameters: params];
    }
    
    /* Execute the update */
    if (![stmt executeUpdateAndReturnError: &error]) {
        _error = error;
        return;
    }
    
    /* Clean up */
    [stmt close];
}

/**
 * Execute an UPDATE statement for the migration.
 *
 * The statement will be executed within the context of the migration's transaction handling.
 *
 * @param stmt The statement to execute. Any additional parameters will be handled via standard PLDatabase parameter interpolation.
 */
- (void) executeUpdate: (NSString *) statement, ... {
    va_list ap;
    va_start(ap, statement);
    [self executeUpdate: statement args: ap];
    va_end(ap);
}

// property getter
- (void (^)(NSString *statement, ...)) update {
    return ^(NSString *statement, ...) {
        va_list ap;
        va_start(ap, statement);
        [self executeUpdate: statement args: ap];
        va_end(ap);
    };
}


@end

/**
 * Provides an easy-to-use API for building versioned migrations for use with PLDatabaseMigrationManager.
 * 
 * The class is mutable; it may be considered thread-safe if new migrations are
 */
@implementation ANTDatabaseMigrationBuilder {
@private
    /** Registered migration blocks */
    NSMutableDictionary *_actions;
}

/**
 * Initialize a new migration builder.
 */
- (instancetype) init {
    if ((self = [super init]) == nil)
        return nil;

    _actions = [NSMutableDictionary dictionary];
    
    return self;
}

/**
 * Register a migration with the given version and action. If a migration for
 * the given version has already been registered, it will be replaced.
 *
 * @param version The migration version. This is the version number to be set on the database after the migration
 * has completed.
 * @param action The migration action to be executed. An ANTDatabaseMigrationState instance will be passed to @a action,
 * upon which database updates may be issued.
 */
- (void) addMigrationWithVersion: (NSUInteger) version action: (void (^)(ANTDatabaseMigrationState *state)) action {
    migration_block_t b = ^(id<PLDatabase> db, NSError **outError) {
        /* Perform the action */
        ANTDatabaseMigrationState *state = [[ANTDatabaseMigrationState alloc] initWithDatabase: db];
        action(state);

        /* Check the result */
        if (state.error != nil) {
            *outError = state.error;
            return NO;
        }
        
        return YES;
    };

    [_actions setObject: [b copy] forKey: @(version)];
}

// from PLDatabaseMigrationDelegate protocol
- (BOOL) migrateDatabase: (id<PLDatabase>) database currentVersion: (int) currentVersion newVersion: (int *) newVersion error: (NSError **) outError {
    NSArray *versions = [[_actions allKeys] sortedArrayUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
        /* Sort ascending */
        return [obj1 compare: obj2];
    }];
    
    /* Appply the migrations */
    for (NSNumber *version in versions) {
        /* Skip completed migrations */
        if ([version intValue] <= currentVersion)
            continue;
        
        migration_block_t block = [_actions objectForKey: version];
        if (!block(database, outError))
            return NO;
        
        *newVersion = [version intValue];
    }

    return YES;
}

// property getter
- (void (^)(NSUInteger version, void (^action)(ANTDatabaseMigrationState *))) migration {
    return ^(NSUInteger version, void (^action)(ANTDatabaseMigrationState *state)) {
        [self addMigrationWithVersion: version action: action];
    };
}

@end
