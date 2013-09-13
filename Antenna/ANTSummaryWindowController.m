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

#import "ANTSummaryWindowController.h"
#import "AntennaAppDelegate.h"

@interface ANTSummaryWindowController () <NSWindowDelegate, NSTableViewDataSource>

@end

/**
 * Manages the summary view.
 */
@implementation ANTSummaryWindowController {
    /** The app delegate */
    __weak IBOutlet AntennaAppDelegate *_appDelegate;
    
    /** Managed table view */
    __weak IBOutlet NSTableView *_tableView;
    
    /** Backing ANTRadarSummaryResponse values, if any. Nil if none have been loaded. */
    NSMutableArray *_summaries;
}

- (void) windowDidLoad {
    [super windowDidLoad];
    
    [_tableView setAllowsColumnSelection: NO];
}

- (void) awakeFromNib {
    [_tableView setAllowsColumnSelection: NO];
}

// Delegate method for a failed summary network fetch.
- (void) summaryAlertDidEnd: (NSAlert *) alert returnCode: (NSInteger) returnCode contextInfo: (void *) contextInfo {
    // TODO - recovery support
}

// from NSWindowDelegate protocol
- (void) windowDidBecomeMain: (NSNotification *) notification {
    /* Load all summaries */
    [_appDelegate.networkClient requestSummariesForSection: @"Open" completionHandler: ^(NSArray *summaries, NSError *error) {
        if (error != nil) {
            [[NSAlert alertWithError: error] beginSheetModalForWindow: self.window modalDelegate: self didEndSelector: @selector(summaryAlertDidEnd:returnCode:contextInfo:) contextInfo: nil];
            return;
        }

        _summaries = [summaries mutableCopy];
        [_tableView reloadData];
    }];
}

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


@end
