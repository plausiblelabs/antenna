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

#import "ANTRadarsWindowController.h"

@interface ANTRadarsWindowController ()

@end

/**
 * Manages the primary 'viewer' window.
 */
@implementation ANTRadarsWindowController

- (id) init {
    if ((self = [super initWithWindowNibName: [self className] owner: self]) == nil)
        return nil;
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (NSInteger) outlineView: (NSOutlineView *) outlineView numberOfChildrenOfItem: (id) item {
    if (item == nil)
        return 2;
    return 0;
}

- (id) outlineView: (NSOutlineView *) outlineView child: (NSInteger) index ofItem: (id) item {
    if (item == nil)
        return @"Item";
    return nil;
}

- (id) outlineView: (NSOutlineView *) outlineView objectValueForTableColumn: (NSTableColumn *) tableColumn byItem: (id) item {
    return item;
}

- (BOOL) outlineView: (NSOutlineView *) outlineView isItemExpandable: (id) item {
    return YES;
}

@end
