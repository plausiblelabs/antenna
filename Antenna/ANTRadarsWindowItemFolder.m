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

/**
 * A standard single section (eg, folder) item in the Radars Window source list.
 */
@implementation ANTRadarsWindowItemFolder

@synthesize title = _title;
@synthesize icon = _icon;
@synthesize children = _children;

/**
 * Return a new instance.
 *
 * @param title The instance's title.
 * @param icon The instance's custom icon, or nil to use the default.
 */
+ (instancetype) itemWithTitle: (NSString *) title icon: (NSImage *) icon {
    return [[self alloc] initWithTitle: title icon: icon];
}


/**
 * Initialize a new instance.
 *
 * @param title Title of the source item.
 * @param children Child elements.
 */
- (instancetype) initWithTitle: (NSString *) title icon: (NSImage *) icon {
    PLSuperInit();
    
    _title = title;
    _icon = icon;
    
    return self;
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
