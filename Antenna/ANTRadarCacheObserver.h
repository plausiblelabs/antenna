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

@class ANTRadarCache;

/**
 * Implement the ANTLocalRadarCacheObserver protocol to observe state events
 * dispatched by the ANTLocalRadarCache.
 */
@protocol ANTRadarCacheObserver <NSObject>
@optional

/**
 * Sent when radars with a given @a openState have been updated.
 *
 * @param cache The sending cache.
 * @param updatedRadarIds The radar ids (numbers) corresponding to the updated radars.
 * @param removedRadarIds The radar ids (numbers) corresponding to the removed radars.
 *
 * Note that the dispatched ordering of observer messages are not gauranteed; listeners should
 * not rely on the values here to provide the current Radar state, and should instead consult
 * the cache directly.
 */
- (void) radarCache: (ANTRadarCache *) cache didUpdateCachedRadarsWithIds: (NSSet *) updatedRadarIds didRemoveCachedRadarsWithIds: (NSSet *) removedRadarIds;

@end
