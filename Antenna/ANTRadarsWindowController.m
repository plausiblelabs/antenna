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
#import "ANTRadarsWindowItemDataSource.h"

#import <PLFoundation/PLFoundation.h>

#import "ANTRadarsWindowItemHeader.h"
#import "ANTRadarsWindowItemFolder.h"

#import "PXSourceList.h"

@interface ANTRadarsWindowController () <PXSourceListDelegate, PXSourceListDataSource, ANTNetworkClientObserver, NSTableViewDataSource, NSTableViewDelegate>
@end

/**
 * Manages the primary 'viewer' window.
 */
@implementation ANTRadarsWindowController {
@private
    /** Backing network client */
    ANTNetworkClient *_client;
    
    /** Local radar cache */
    ANTLocalRadarCache *_cache;

    /** Left-side source tree */
    __weak IBOutlet PXSourceList *_sourceList;

    /** Items listed in the left-hand source view */
    NSArray *_sourceItems;

    /** Summary table table view */
    __weak IBOutlet NSTableView *_summaryTableView;
    
    /** Summary table's title menu */
    __weak IBOutlet NSMenu *_summaryTableHeaderMenu;

    /** Any in-progress fetch request, or nil if none */
    PLCancelTicketSource *_fetchTicketSource;
    
    /** Backing ANTRadarSummaryResponse values, if any. Nil if none have been loaded. */
    NSMutableArray *_summaries;

    /** Background serial dispatch queue for serialized, off-main-thread operations */
    dispatch_queue_t _queue;
}

/**
 * Initialize a new ANTRadarsWindowController instance.
 *
 * @param client The backing network Radar client.
 * @param cache The local radar cache.
 */
- (id) initWithClient: (ANTNetworkClient *) client cache: (ANTLocalRadarCache *) cache {
    if ((self = [super initWithWindowNibName: [self className] owner: self]) == nil)
        return nil;
    
    _client = client;
    _cache = cache;
    _queue = dispatch_queue_create([[self className] UTF8String], DISPATCH_QUEUE_SERIAL);
    
    NSImage *folderIcon = [NSImage imageNamed: NSImageNameFolder];
    NSImage *smartFolderIcon = [NSImage imageNamed: NSImageNameFolderSmart];
    ANTRadarsWindowItemHeader *radarItem = [ANTRadarsWindowItemHeader itemWithTitle: NSLocalizedString(@"My Radars", nil) children: @[
        [ANTRadarsWindowItemFolder itemWithClient: client title: NSLocalizedString(@"Open", nil) icon: folderIcon sectionNames: @[ANTNetworkClientFolderTypeOpen]],
        [ANTRadarsWindowItemFolder itemWithClient: client title: NSLocalizedString(@"Closed", nil) icon: folderIcon sectionNames: @[ANTNetworkClientFolderTypeClosed, ANTNetworkClientFolderTypeArchive]],
        [ANTRadarsWindowItemFolder itemWithClient: client title: NSLocalizedString(@"Recently Updated", nil) icon: smartFolderIcon sectionNames: @[@"Open"]] // TODO - Needs to be a custom source
    ]];

    // TODO - Unimplemented
    ANTRadarsWindowItemHeader *openRadarItem = [ANTRadarsWindowItemHeader itemWithTitle: NSLocalizedString(@"My Public Radars", nil) children: @[
        [ANTRadarsWindowItemFolder itemWithClient: client title: NSLocalizedString(@"Open", nil) icon: folderIcon sectionNames: @[@"Open"]],
        [ANTRadarsWindowItemFolder itemWithClient: client title: NSLocalizedString(@"Closed", nil) icon: folderIcon sectionNames: @[@"Open"]],
        [ANTRadarsWindowItemFolder itemWithClient: client title: NSLocalizedString(@"Watching", nil) icon: smartFolderIcon sectionNames: @[@"Open"]],
        [ANTRadarsWindowItemFolder itemWithClient: client title: NSLocalizedString(@"Recently Updated", nil) icon: smartFolderIcon sectionNames: @[@"Open"]]
    ]];

    _sourceItems = @[radarItem, openRadarItem];
    
    [_client addObserver: self dispatchContext: [PLGCDDispatchContext mainQueueContext]];

    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

// ANTNetworkClientDidChangeAuthState notification
- (void) networkClientDidChangeAuthState: (ANTNetworkClient *) client {
    if (_client.authState != ANTNetworkClientAuthStateAuthenticated)
        return;
}

- (void) windowDidLoad {
    [super windowDidLoad];

    /* Disallow column selection */
    [_summaryTableView setAllowsColumnSelection: NO];

    /* Expand all by default. TODO: Should we save/restore the user's preferences here? */
    [_sourceList expandItem: nil expandChildren: YES];
}

// Enable/disable columns
- (void) toggleColumn: (NSMenuItem *) sender {
    NSTableColumn *column = [sender representedObject];
    if ([sender state] == NSOnState) {
        [column setHidden: YES];
    } else {
        [column setHidden: NO];
    }
}

// from NSMenuDelegate protocol
- (void) menuWillOpen: (NSMenu *) menu {
    assert(menu == _summaryTableHeaderMenu);
    
    [menu removeAllItems];
    for (NSTableColumn *column in [_summaryTableView tableColumns]) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle: [column.headerCell stringValue]
                                                      action: @selector(toggleColumn:)
                                               keyEquivalent: @""];
        
        if ([column isHidden]) {
            [item setState: NSOffState];
        } else {
            [item setState: NSOnState];
        }
        
        item.target = self;
        item.representedObject = column;
        [menu addItem: item];
    }
}


// Delegate method for a failed summary network fetch.
- (void) summaryAlertDidEnd: (NSAlert *) alert returnCode: (NSInteger) returnCode contextInfo: (void *) contextInfo {
    // TODO - recovery support
}

#pragma mark Table View

// from NSTableViewDataSource protocol
- (id) tableView: (NSTableView *) aTableView objectValueForTableColumn: (NSTableColumn *) aTableColumn row: (NSInteger) rowIndex {
    BOOL (^Check)(NSString *) = ^(NSString *ident) {
        return [[aTableColumn identifier] isEqualToString: ident];
    };
    
    ANTRadarSummaryResponse *summary = [_summaries objectAtIndex: rowIndex];
    
#define RetVal(_ident, _data) if (Check(_ident)) return _data;
    RetVal(@"id", summary.radarId);
    RetVal(@"state", summary.stateName);
    RetVal(@"title", summary.title);
    RetVal(@"date", summary.originatedDate);
    RetVal(@"component", summary.componentName);
#undef RetVal
    
    return nil;
}

// from NSTableViewDataSource protocol
- (void) tableView: (NSTableView *) tableView sortDescriptorsDidChange: (NSArray *) oldDescriptors {
    [_summaries sortUsingDescriptors: [tableView sortDescriptors]];
    [tableView reloadData];
}


// from NSTableViewDataSource protocol
- (NSInteger) numberOfRowsInTableView: (NSTableView *) aTableView {
    return [_summaries count];
}

// from NSTableViewDataSource protocol
- (void) tableViewSelectionDidChange: (NSNotification *) aNotification {
    NSIndexSet *selection = [_summaryTableView selectedRowIndexes];
    if ([selection count] > 1) {
        NSLog(@"TODO: Handle multi-selection");
        return;
    }
    
    // XXX - We should actually display the radar ...
    ANTRadarSummaryResponse *summary = [_summaries objectAtIndex: [selection firstIndex]];
    [_client requestRadarWithId: summary.radarId cancelTicket: [PLCancelTicketSource new].ticket dispatchContext: [PLGCDDispatchContext mainQueueContext] completionHandler:^(ANTRadarResponse *radar, NSError *error) {
        NSLog(@"Radar: %@", radar.title);
    }];
}

#pragma mark Source List

// from PXSourceListDataSource protocol
- (NSUInteger) sourceList: (PXSourceList*) sourceList numberOfChildrenOfItem: (id) item {
	if (item == nil)
		return [_sourceItems count];

    id<ANTRadarsWindowItemDataSource> ds = item;
    if (ds.children == nil)
        return 0;

    return [ds.children count];
}

// from PXSourceListDataSource protocol
- (id) sourceList: (PXSourceList *) aSourceList child: (NSUInteger) index ofItem: (id) item {
	if(item == nil)
		return [_sourceItems objectAtIndex: index];

    id<ANTRadarsWindowItemDataSource> ds = item;
    return [ds.children objectAtIndex: index];
}

// from PXSourceListDataSource protocol
- (id) sourceList: (PXSourceList *) aSourceList objectValueForItem: (id) item {
    id<ANTRadarsWindowItemDataSource> ds = item;
    return ds.title;
}

// from PXSourceListDataSource protocol
- (void) sourceList: (PXSourceList *) aSourceList setObjectValue: (id) object forItem: (id) item {
    // TODO
	// [item setTitle:object];
}

// from PXSourceListDataSource protocol
- (BOOL) sourceList: (PXSourceList *) aSourceList isItemExpandable: (id) item {
    id<ANTRadarsWindowItemDataSource> ds = item;

    if (ds.children != nil && [ds.children count] > 0)
        return YES;
    
    return NO;
}

// from PXSourceListDataSource protocol
- (BOOL) sourceList: (PXSourceList*) aSourceList itemHasBadge: (id) item {
    // TODO
	return NO;
}

// from PXSourceListDataSource protocol
- (NSInteger) sourceList: (PXSourceList*) aSourceList badgeValueForItem: (id) item {
    // TODO
	return 0;
}

// from PXSourceListDataSource protocol
- (BOOL) sourceList: (PXSourceList*) aSourceList itemHasIcon: (id) item {
    id<ANTRadarsWindowItemDataSource> ds = item;
    if (ds.icon != nil)
        return YES;
    
    return NO;
}

// from PXSourceListDataSource protocol
- (NSImage *) sourceList: (PXSourceList *) aSourceList iconForItem: (id) item {
    id<ANTRadarsWindowItemDataSource> ds = item;
    return ds.icon;
}

// from PXSourceListDataSource protocol
- (NSMenu *) sourceList: (PXSourceList *) aSourceList menuForEvent:(NSEvent*)theEvent item:(id)item {
	if ([theEvent type] == NSRightMouseDown || ([theEvent type] == NSLeftMouseDown && ([theEvent modifierFlags] & NSControlKeyMask) == NSControlKeyMask)) {
		NSMenu * m = [[NSMenu alloc] init];
		if (item != nil) {
			[m addItemWithTitle:[item title] action:nil keyEquivalent:@""];
		} else {
			[m addItemWithTitle:@"clicked outside" action:nil keyEquivalent:@""];
		}
		return m;
	}
	return nil;
}

// from PXSourceListDelegate protocol
- (BOOL) sourceList: (PXSourceList *) aSourceList isGroupAlwaysExpanded: (id) group {
    return NO;
}

// from PXSourceListDelegate protocol
- (void) sourceListSelectionDidChange: (NSNotification *) notification {
    /* Cancel any pending requests */
    [_fetchTicketSource cancel];
    _fetchTicketSource = nil;
    
    /* Clear the current view */
    [_summaries removeAllObjects];
    [_summaryTableView reloadData];

    /* Fetch all selected indexes that support summary loading */
    NSIndexSet *selectedIndexes = [_sourceList selectedRowIndexes];
    NSMutableArray *dataSources = [NSMutableArray arrayWithCapacity: [selectedIndexes count]];
    [selectedIndexes enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
        id<ANTRadarsWindowItemDataSource> ds = [_sourceList itemAtRow: idx];
        if (![ds respondsToSelector: @selector(radarSummariesWithCancelTicket:dispatchContext:completionHander:)])
            return;

        [dataSources addObject: [_sourceList itemAtRow: idx]];
    }];
    
    /* Set up a new ticket source */

    /* Fetch all data for the selected data sources */
    PLGCDDispatchContext *context = [[PLGCDDispatchContext alloc] initWithQueue: _queue];
    NSMutableArray *results = [NSMutableArray array];
    __block NSUInteger remaining = [dataSources count];

    for (id<ANTRadarsWindowItemDataSource> ds in dataSources) {
        /* Saved copy of the sort descriptors to allow for speculative sorting on the background thread. */
        NSArray *sortDescriptors = [_summaryTableView sortDescriptors];
        [ds radarSummariesWithCancelTicket: _fetchTicketSource.ticket dispatchContext: context completionHander: ^(NSArray *summaries, NSError *error) {
            /* Cancel all other pending requests on error */
            if (error != nil) {
                [_fetchTicketSource cancel];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSAlert alertWithError: error] beginSheetModalForWindow: self.window modalDelegate: self didEndSelector: @selector(summaryAlertDidEnd:returnCode:contextInfo:) contextInfo: nil];
                });
                return;
            }
            
            /* Add results */
            [results addObjectsFromArray: summaries];
            
            /* Check for completion */
            remaining--;
            if (remaining == 0) {
                /* Try to perform sorting on the background queue (and hope that we don't need to re-sort).*/
                [results sortUsingDescriptors: sortDescriptors];

                /* We're running on a background dispatch queue -- switch back to the main queue */
                [[PLGCDDispatchContext mainQueueContext] performWithCancelTicket: _fetchTicketSource.ticket block:^{
                    /* If the sort descriptors have changed, we'll need to re-sort here */
                    if (![sortDescriptors isEqual: _summaryTableView.sortDescriptors]) {
                        [results sortUsingDescriptors: [_summaryTableView sortDescriptors]];
                    }

                    _summaries = [results mutableCopy];
                    [_summaryTableView reloadData];
                }];
            }
        }];
    }
}


- (void) sourceListDeleteKeyPressedOnRows: (NSNotification *) notification {
	NSIndexSet *rows = [[notification userInfo] objectForKey:@"rows"];
	
	NSLog(@"Delete key pressed on rows %@", rows);
	
	//Do something here
}

@end
