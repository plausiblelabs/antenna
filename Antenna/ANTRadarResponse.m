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

#import "ANTRadarResponse.h"
#import <PLFoundation/PLFoundation.h>

/**
 * A single Radar response.
 */
@implementation ANTRadarResponse

- (instancetype) initWithTitle: (NSString *) title
                      comments: (NSArray *) comments
                      resolved: (BOOL) resolved
              lastModifiedDate: (NSDate *) lastModifiedDate
                   enclosureId: (NSString *) enclosureId
{
    PLSuperInit();
    
    _title = title;
    _comments = comments;
    _resolved = resolved;
    _lastModifiedDate = lastModifiedDate;
    _enclosureId = enclosureId;

    return self;
}

@end

/**
 * A Radar comment response.
 */
@implementation ANTRadarCommentResponse

- (instancetype) initWithAuthorName: (NSString *) authorName
                            content: (NSString *) content
                          timestamp: (NSDate *) timestamp
{
    PLSuperInit();
    
    _authorName = authorName;
    _content = content;
    _timestamp = timestamp;

    return self;
}

@end