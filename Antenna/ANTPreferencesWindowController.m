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
#import "ANTPreferencesAccountCellView.h"
#import "ANTPreferencesAppleAccountViewController.h"

/* Hard-coded table view rows for the 'Accounts' preferences tab */
enum ACCOUNT_ROW {
    /** Apple ID account row. */
    ACCOUNT_ROW_APPLE_ID = 0,
    
    /** Open Radar account row. */
    ACCOUNT_ROW_OPEN_RADAR = 1
};

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
    
    /** Account table view; used to select settings for a specific account type in the Accounts tab. */
    __weak IBOutlet NSTableView *_accountsTableView;
    
    /** Account box; used to display the per Account configuration int he Accounts tab. */
    __weak IBOutlet NSBox *_accountBox;

    /** Apple login view controller; used in the Accounts tab; lazy-loaded, may be nil. */
    ANTPreferencesAppleAccountViewController *_appleAccountViewController;
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

- (void) windowDidLoad {
    [super windowDidLoad];

    // TODO: This should default to whatever was last selected
    [_toolbar setSelectedItemIdentifier: @"general"];
    [_tabView selectTabViewItem: _generalTabItem];
}

// General toolbar item selected
- (IBAction) didSelectGeneralToolBarItem: (id) sender {
    [_tabView selectTabViewItem: _generalTabItem];
}

// Account toolbar item selected
- (IBAction) didSelectAccountsToolBarItem: (id) sender {
    [_tabView selectTabViewItem: _accountTabItem];
    [self configureAccountBox];
}

// Account tableview row selected
- (void) tableViewSelectionDidChange: (NSNotification *) aNotification {
    [self configureAccountBox];
}

/**
 * Configure the internal account view according to the current
 * table selection in the accounts tab.
 */
- (void) configureAccountBox {
    NSInteger row = [_accountsTableView selectedRow];
    
    if (row == ACCOUNT_ROW_APPLE_ID) {
        if (_appleAccountViewController == nil) {
            _appleAccountViewController = [[ANTPreferencesAppleAccountViewController alloc] initWithPreferences: _prefs];
        }
        [_accountBox setContentView: [_appleAccountViewController view]];
    } else if (row == ACCOUNT_ROW_OPEN_RADAR) {
        // TODO
        [_accountBox setContentView: nil];
    } else {
        // What *are* you?
        abort();
    }
}

// from NSTableViewDataSource protocol
- (NSInteger) numberOfRowsInTableView: (NSTableView *) tableView {
    return 2;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    /* Fetch (or create) a re-usable view */
    ANTPreferencesAccountCellView *result = [tableView makeViewWithIdentifier: @"AccountCell" owner:self];
    
    if (row == ACCOUNT_ROW_APPLE_ID) {
        if ([_prefs appleID] != nil) {
            [result.textField setStringValue: [_prefs appleID]];
            [result.detailTextField setStringValue: NSLocalizedString(@"Apple ID", nil)];
            [result.imageView setImage: [NSImage imageNamed: NSImageNameMobileMe]];
        } else {
            [result.textField setStringValue: NSLocalizedString(@"(Inactive)", nil)];
        }
        
    } else if (row == ACCOUNT_ROW_OPEN_RADAR) {
        [result.textField setStringValue: NSLocalizedString(@"Open Radar", nil)];
        [result.detailTextField setStringValue: NSLocalizedString(@"(Inactive)", nil)];
        [result.imageView setImage: [NSImage imageNamed: @"openradar_icon.pdf"]];
    } else {
        // What *are* you?
        abort();
    }
    
    /* Configure and return the cell */
    return result;
}

@end
