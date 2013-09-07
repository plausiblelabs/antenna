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

#import "ANTPreferencesWindowController.h"

@interface ANTPreferencesWindowController () <NSTableViewDataSource, NSTableViewDelegate>

@end

@implementation ANTPreferencesWindowController {
@private
    /** Backing application preferences. */
    ANTPreferences *_prefs;
    
    /** Preferences toolbar.*/
    __weak IBOutlet NSToolbar *_toolbar;

    /** Preferences content view */
    __weak IBOutlet NSTabView *_tabView;
    
    /** General preferences tab item */
    __weak IBOutlet NSTabViewItem *_generalTabItem;
    
    /** Account preferences tab item */
    __weak IBOutlet NSTabViewItem *_accountTabItem;
}

/**
 * Initialize a new instance with @a preferences.
 *
 * @param preferences Application preferences.
 */
- (instancetype) initWithPreferences: (ANTPreferences *) preferences {
    if ((self = [super initWithWindowNibName: [self className] owner: self]) == nil)
        return nil;

    _prefs = preferences;

    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    // TODO: This should default to whatever was last selected
    [_toolbar setSelectedItemIdentifier: @"general"];
    [_tabView selectTabViewItem: _generalTabItem];
}

- (IBAction) didSelectGeneralToolBarItem: (id) sender {
    [_tabView selectTabViewItem: _generalTabItem];
}

- (IBAction) didSelectAccountsToolBarItem: (id) sender {
    [_tabView selectTabViewItem: _accountTabItem];
}

// from NSTableViewDataSource protocol
- (NSInteger) numberOfRowsInTableView: (NSTableView *) tableView {
    return 2; // TODO
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    /* Fetch (or create) a re-usable view */
    NSTableCellView *result = [tableView makeViewWithIdentifier: @"AccountCell" owner:self];
    
    
    /* Configure and return the cell */
    return result;
}

@end
