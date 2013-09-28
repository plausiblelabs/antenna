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

#import "ANTRadarsWindowItemFolder.h"

/* Maximum number of Radars to be displayed; this is a completely arbitrary sanity check. */
#define MAX_RADARS 10000

/**
 * A standard single section (eg, folder) item in the Radars Window source list.
 */
@implementation ANTRadarsWindowItemFolder {
@private
    /** Network client */
    ANTNetworkClient *_client;

    /** Radar sections represented by this folder */
    NSArray *_sectionNames;
}

@synthesize title = _title;
@synthesize icon = _icon;
@synthesize children = _children;

/**
 * Return a new instance.
 *
 * @param title The instance's title.
 * @param icon The instance's custom icon, or nil to use the default.
 * @param sectionNames The section names to fetch for this folder.
 */
+ (instancetype) itemWithClient: (ANTNetworkClient *) client title: (NSString *) title icon: (NSImage *) icon sectionNames: (NSArray *) sectionNames {
    return [[self alloc] initWithClient: client title: title icon: icon sectionNames: sectionNames];
}


/**
 * Initialize a new instance.
 *
 * @param title Title of the source item.
 * @param children Child elements.
 * @param sectionNames The section names to fetch for this folder.
 */
- (instancetype) initWithClient: (ANTNetworkClient *) client title: (NSString *) title icon: (NSImage *) icon sectionNames: (NSArray *) sectionNames {
    PLSuperInit();
    
    _title = title;
    _icon = icon;
    _client = client;
    _sectionNames = sectionNames;

    return self;
}

// from ANTRadarsWindowItemDataSource protocol
- (void) radarSummariesWithCancelTicket: (PLCancelTicket *) ticket dispatchContext: (id<PLDispatchContext>) context completionHander: (void (^)(NSArray *, NSError *))handler {
    [_client requestSummariesForSections: _sectionNames maximumCount: MAX_RADARS cancelTicket: ticket dispatchContext: context completionHandler: handler];
}

// from NSCopying protocol
- (instancetype) copyWithZone:(NSZone *)zone {
    return self;
}

// from NSCopying protocol
- (instancetype) copy {
    return [self copyWithZone: nil];
}

@end
