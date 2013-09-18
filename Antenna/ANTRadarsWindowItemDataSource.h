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
#import <PLFoundation/PLFoundation.h>

/**
 * Radar window data source.
 */
@protocol ANTRadarsWindowItemDataSource <NSObject, NSCopying>
@required

/** The source item's title. */
@property(nonatomic, readonly) NSString *title;

/** The item's icon, if any. */
@property(nonatomic, readonly) NSImage *icon;

/** Child elements, if any. */
@property(nonatomic, readonly) NSArray *children;

@optional

/**
 * Fetch all summaries for this item.
 *
 * @param ticket Cancellation ticket for the request.
 * @param context The dispatch context on which @a handler will be called.
 * @param handler The request completion handler. On success, the error parameter will be nil, and an array
 * of ANTRadarSummaryResponse values will be provided. On failure, the error parameter will be non-nill, and
 * an error in the ANTErrorDomain will be provided.
 */
- (void) radarSummariesWithCancelTicket: (PLCancelTicket *) ticket
                        dispatchContext: (id<PLDispatchContext>) context
                       completionHander: (void (^)(NSArray *summaries, NSError *error)) handler;

@end
