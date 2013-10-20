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
#import "ANTRadarCacheAccount.h"

@class ANTRadarCache;

/**
 * Implement the ANTRadarCacheDataSource to provide cachable Radar data
 * to the ANTRadarcache.
 */
@protocol ANTRadarCacheDataSource <NSObject>

/**
 * Return all configured ANTRadarCacheAccount instances.
 *
 * @param cache The requesting cache instance.
 */
- (NSArray *) accountsForRadarCache: (ANTRadarCache *) cache;


/**
 * Return the network client instance to be used to synchronize @a cache for @a account.
 *
 * @param cache The requesting cache instance.
 * @param account 
 */
- (ANTNetworkClient *) radarClientForRadarCache: (ANTRadarCache *) cache account: (ANTRadarCacheAccount *) account;

@end
