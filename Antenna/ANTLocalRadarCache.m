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

#import "ANTLocalRadarCache.h"
#import <PLFoundation/PLFoundation.h>
#import <PlausibleDatabase/PlausibleDatabase.h>

#import "ANTLocalRadarDatabase.h"

#import <objc/runtime.h>

/**
 * Manages a local Radar cache.
 */
@implementation ANTLocalRadarCache {
@private
    /** Our storage directory */
    NSString *_path;

    /** Backing database */
    ANTLocalRadarDatabase *_db;

    /** The backing network client */
    ANTNetworkClient *_client;
}

/**
 * Initialize a new Radar cache instance.
 *
 * @param client The Radar network client to be used for Radar synchronization.
 * @param cachePath The path at which the cache should be stored.
 * @param outError If initialization of the cache fails, an error in the ANTErrorDomain will be returned.
 *
 * @return Returns an initialized instance on success, or nil on failure.
 */
- (instancetype) initWithClient: (ANTNetworkClient *) client path: (NSString *) path error: (NSError **) outError {
    PLSuperInit();
    NSError *error;
    
    _path = path;
    _client = client;

    /* Set up the destination directory */
    NSFileManager *fm = [NSFileManager new];
    if (![fm createDirectoryAtPath: path withIntermediateDirectories: YES attributes: @{NSFilePosixPermissions: @(0750)} error: &error]) {
        /* This should only happen on a misconfigured host */
        NSLog(@"Failed to create %s path %@", class_getName([self class]), path);
        [NSError pl_errorWithDomain: ANTErrorDomain
                               code: ANTErrorStorageFailure
               localizedDescription: [error localizedDescription]
             localizedFailureReason: [error localizedFailureReason]
                    underlyingError: error
                           userInfo: nil];
        return nil;
    }
    
    /* Set up the backing database */
    NSString *dbPath = [_path stringByAppendingPathComponent: @"radar.db"];
    PLSqliteConnectionProvider *connectionProvider;
    connectionProvider = [[PLSqliteConnectionProvider alloc] initWithPath: dbPath
                                                                    flags: SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_SHAREDCACHE|SQLITE_OPEN_FULLMUTEX];
    _db = [[ANTLocalRadarDatabase alloc] initWithConnectionProvider: connectionProvider];

    return self;
}

@end
