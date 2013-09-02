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

#import "ANTRadarSummaryResponse.h"

/**
 * An issue summary network response.
 */
@implementation ANTRadarSummaryResponse

/**
 * Initialize a new instance.
 */
- (id) initWithRadarId: (NSString *) radarId
             stateName: (NSString *) stateName
               summary: (NSString *) summary
         componentName: (NSString *) componentName
                hidden: (BOOL) hidden
           description: (NSString *) description
        originatedDate: (NSDate *) originatedDate
{
    if ((self = [super init]) == nil)
        return nil;

    _radarId = radarId;
    _stateName = stateName;
    _summary = summary;
    _componentName = componentName;
    _hidden = hidden;
    _description = description;
    _originatedDate = originatedDate;
    
    return self;
}

@end
