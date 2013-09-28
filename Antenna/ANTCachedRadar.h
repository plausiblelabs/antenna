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

@interface ANTCachedRadar : NSObject

- (instancetype) initWithTitle: (NSString *) title
                      resolved: (BOOL) resolved
              lastModifiedDate: (NSDate *) lastModifiedDate
                        unread: (BOOL) unread;

/** The issue title */
@property(nonatomic, readonly) NSString *title;

/** YES if the Radar is marked as resolved, NO otherwise */
@property(nonatomic, readonly, getter=isResolved) BOOL resolved;

/** The time at which this Radar was last modified. */
@property(nonatomic, readonly) NSDate *lastModifiedDate;

/** YES if this Radar is marked as unread, NO otherwise. */
@property(nonatomic, readonly) BOOL unread;

@end
