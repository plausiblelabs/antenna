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
#import "ANTRadarSummaryResponse.h"

@interface ANTRadarSummariesResponse : NSObject

- (instancetype) initWithRowStart: (NSUInteger) rowStart rowsInCache: (NSUInteger) rowsInCache summaries: (NSArray *) summaries;

/** The starting row reference; this is used to perform paginated loading of the summary data. */
@property(nonatomic, readonly) NSUInteger rowStart;

/** The total number of rows available. While rowStart + [summaries count] < rowsInCache, additional data is available. */
@property(nonatomic, readonly) NSUInteger rowsInCache;

/** An ordered array of ANTRadarSummaryResponse values. */
@property(nonatomic, readonly) NSArray *summaries;

/** YES if additional rows are available from the server (rowStart + [summaries count] < rowsInCache) */
@property(nonatomic, readonly) BOOL hasAdditionalRows;

@end
