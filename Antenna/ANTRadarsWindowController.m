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
#import <PLFoundation/PLFoundation.h>

@interface ANTRadarsWindowController () @end

@interface ANTRadarsWindowSourceItem : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate, NSCopying>

+ (instancetype) itemWithTitle: (NSString *) title
                      children: (NSArray *) children;

+ (instancetype) itemWithTitle: (NSString *) title
                          icon: (NSImage *) icon;

- (instancetype) initWithTitle: (NSString *) title icon: (NSImage *) icon children: (NSArray *) children;

/** The source item's title. */
@property(nonatomic, readonly) NSString *title;

/** The item's icon, if any. */
@property(nonatomic, readonly) NSImage *icon;

/** Child elements, if any. */
@property(nonatomic, readonly) NSArray *children;

@end

/**
 * Manages the primary 'viewer' window.
 */
@implementation ANTRadarsWindowController {
@private
    /** Left-side source tree */
    __weak IBOutlet NSOutlineView *_outlineView;

    /** Items listed in the left-hand source view */
    NSArray *_sourceItems;
}

- (id) init {
    if ((self = [super initWithWindowNibName: [self className] owner: self]) == nil)
        return nil;
    
    ANTRadarsWindowSourceItem *radarItem = [ANTRadarsWindowSourceItem itemWithTitle: NSLocalizedString(@"My Radars", nil) children: @[
        [ANTRadarsWindowSourceItem itemWithTitle: NSLocalizedString(@"Open", nil) icon: nil],
        [ANTRadarsWindowSourceItem itemWithTitle: NSLocalizedString(@"Closed", nil) icon: nil],
        [ANTRadarsWindowSourceItem itemWithTitle: NSLocalizedString(@"Recently Updated", nil) icon: [NSImage imageNamed: NSImageNameFolderSmart]]
    ]];

    ANTRadarsWindowSourceItem *openRadarItem = [ANTRadarsWindowSourceItem itemWithTitle: NSLocalizedString(@"My Public Radars", nil) children: @[
        [ANTRadarsWindowSourceItem itemWithTitle: NSLocalizedString(@"Open", nil) icon: nil],
        [ANTRadarsWindowSourceItem itemWithTitle: NSLocalizedString(@"Closed", nil) icon: nil],
        [ANTRadarsWindowSourceItem itemWithTitle: NSLocalizedString(@"Watching", nil) icon: [NSImage imageNamed: NSImageNameFolderSmart]],
        [ANTRadarsWindowSourceItem itemWithTitle: NSLocalizedString(@"Recently Updated", nil) icon: [NSImage imageNamed: NSImageNameFolderSmart]]
    ]];

    _sourceItems = @[radarItem, openRadarItem];

    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    /* Expand all by default. TODO: Should we save/restore the user's preferences here? */
    [_outlineView expandItem: nil expandChildren: YES];
}

- (NSView *) outlineView: (NSOutlineView *) outlineView viewForTableColumn: (NSTableColumn *) column item: (id) treeNode {
    ANTRadarsWindowSourceItem *item = treeNode;
    NSTableCellView *view;

    if ([_sourceItems containsObject: item]) {
        view = [outlineView makeViewWithIdentifier: @"HeaderCell" owner: self];
    } else {
        view = [outlineView makeViewWithIdentifier: @"DataCell" owner: self];
        if (item.icon != nil) {
            [[view imageView] setImage: item.icon];
        } else {
            [[view imageView] setImage: [NSImage imageNamed: NSImageNameFolder]];
        }
    }
    
    [[view textField] setStringValue: item.title];
    return view;
}

// from NSOutlineViewDataSource protocol
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    /* Top-level items are not selectable */
    if ([_sourceItems containsObject: item])
        return NO;
    
    return YES;
}

// from NSOutlineViewDataSource protocol
- (BOOL) outlineView: (NSOutlineView *) outlineView isGroupItem: (id) item {
    /* Top-level items use the group style */
    if ([_sourceItems containsObject: item])
        return YES;

    return NO;
}

// from NSOutlineViewDataSource protocol
- (NSInteger) outlineView: (NSOutlineView *) outlineView numberOfChildrenOfItem: (id) item {
    if (item == nil)
        return [_sourceItems count];

    return ((ANTRadarsWindowSourceItem *) item).children.count;
}

// from NSOutlineViewDataSource protocol
- (id) outlineView: (NSOutlineView *) outlineView child: (NSInteger) index ofItem: (id) item {
    if (item == nil)
        return _sourceItems[index];

    return ((ANTRadarsWindowSourceItem *) item).children[index];
}

// from NSOutlineViewDataSource protocol
- (id) outlineView: (NSOutlineView *) outlineView objectValueForTableColumn: (NSTableColumn *) tableColumn byItem: (id) item {
    return item;
}

// from NSOutlineViewDataSource protocol
- (BOOL) outlineView: (NSOutlineView *) outlineView isItemExpandable: (id) item {
    if (((ANTRadarsWindowSourceItem *) item).children.count > 0)
        return YES;

    return NO;
}

@end

/**
 * A single source window item.
 */
@implementation ANTRadarsWindowSourceItem

/**
 * Return a new instance.
 *
 * @param title The instance's title.
 * @param children Child elements.
 */
+ (instancetype) itemWithTitle: (NSString *) title children: (NSArray *) children {
    return [[self alloc] initWithTitle: title icon: nil children: children];
}

/**
 * Return a new instance.
 *
 * @param title The instance's title.
 * @param icon The instance's custom icon, or nil to use the default.
 */
+ (instancetype) itemWithTitle: (NSString *) title icon: (NSImage *) icon {
    return [[self alloc] initWithTitle: title icon: icon children: nil];
}


/**
 * Initialize a new instance.
 *
 * @param title Title of the source item.
 * @param children Child elements.
 */
- (instancetype) initWithTitle: (NSString *) title icon: (NSImage *) icon children: (NSArray *) children {
    PLSuperInit();
    
    _title = title;
    _children = children;
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