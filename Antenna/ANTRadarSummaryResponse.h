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

@interface ANTRadarSummaryResponse : NSObject

- (id) initWithRadarId: (NSNumber *) radarId
             stateName: (NSString *) stateName
                 title: (NSString *) summary
         componentName: (NSString *) componentName
     requiresAttention: (BOOL) requiresAttention
                hidden: (BOOL) hidden
           description: (NSString *) description
        originatedDate: (NSDate *) originatedDate;

/** The Radar issue number for this bug. */
@property(nonatomic, readonly) NSNumber *radarId;

/** The issue state (eg, Open, Closed) */
@property(nonatomic, readonly) NSString *stateName;

/** The issue's title (eg, summary). */
@property(nonatomic, readonly) NSString *title;

/** The component name (eg, "Developer Tools" or "iPhone SDK") */
@property(nonatomic, readonly) NSString *componentName;

/** YES if the Radar is marked as requiring a user response, NO otherwise. */
@property(nonatomic, readonly) BOOL requiresAttention;

/** Whether the issue should be hidden. */
@property(nonatomic, readonly) BOOL hidden;

/** A truncated copy of the issue description. */
@property(nonatomic, readonly) NSString *description;

/** The issue's originated date. */
@property(nonatomic, readonly) NSDate *originatedDate;


@end
