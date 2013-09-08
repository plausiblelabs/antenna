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
#import "ANTPreferencesORAccountViewController.h"

/* Hard-coded table view rows for the 'Accounts' preferences tab */
typedef NS_ENUM(NSInteger, ANTPreferencesWindowAccountRow) {
    /** Apple ID account row. */
    ANTPreferencesWindowAccountRowAppleId = 0,
    
    /** Open Radar account row. */
    ANTPreferencesWindowAccountRowOpenRadar = 1
};

static NSString *ANTPreferencesWindowControllerSelectedToolBarItem = @"ANTPreferencesWindowControllerSelectedToolBarItem";

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
    
    /** Open Radar view controller; used in the Accounts tab; lazy-loaded, may be nil. */
    ANTPreferencesORAccountViewController *_openRadarAccountViewController;
}

/**
 * The restoration identifier used for this controller's window.
 */
+ (NSString *) restorationIdentifier {
    return @"AppPrefs";
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

/**
 * Configure the receiver with the restored state from @a state.
 *
 * @param state A coder object containing the window's previously saved state information.
 * @param completionHandler A Block object to execute with the results of creating the window. This block takes the following parameters:
 *  - The window that was created or nil if the window could not be created.
 *  - An error object if the window was not recognized or could not be created for whatever reason; otherwise, specify nil.
 */
- (void) restoreWindowState: (NSCoder *) state completionHandler: (void (^)(NSWindow *window, NSError *error)) completionHandler {
    NSWindow *window = self.window;
    NSString *identifier = [state decodeObjectForKey: ANTPreferencesWindowControllerSelectedToolBarItem];
    if (identifier != nil)
        [self selectTabItemWithIdentifier: identifier];
    
    completionHandler(window, nil);
}

- (void) windowDidLoad {
    [super windowDidLoad];

    /* Default to 'General' tab */
    [self selectTabItemWithIdentifier: @"general"];
}

// from NSWindowDelegate protocol
- (void) window: (NSWindow *) window willEncodeRestorableState: (NSCoder *) state {
    /* Save the currently selected toolbar item */
    [state encodeObject: [_toolbar selectedItemIdentifier] forKey: ANTPreferencesWindowControllerSelectedToolBarItem];
}

/**
 * Select the tab (and toolbar) item with @a identifier.
 *
 * @param identifier The shared tab/toolbar item identifier.
 */
- (void) selectTabItemWithIdentifier: (NSString *) identifier {
    [_toolbar setSelectedItemIdentifier: identifier];
    [_tabView selectTabViewItemWithIdentifier: identifier];
    [self invalidateRestorableState];

    // TODO - This should be handled by a subsidary 'Accounts' view controller.
    if ([identifier isEqual: @"accounts"]) {
        [self configureAccountBox];
    }
}


// Toolbar item selected
- (IBAction) didSelectToolBarItem: (id) sender {
    [self selectTabItemWithIdentifier: [sender itemIdentifier]];
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
    
    switch ((ANTPreferencesWindowAccountRow)row) {
        case ANTPreferencesWindowAccountRowAppleId:
            if (_appleAccountViewController == nil) {
                _appleAccountViewController = [[ANTPreferencesAppleAccountViewController alloc] initWithPreferences: _prefs];
            }
            [_accountBox setContentView: [_appleAccountViewController view]];
            break;
            
        case ANTPreferencesWindowAccountRowOpenRadar:
            if (_openRadarAccountViewController == nil) {
                _openRadarAccountViewController = [[ANTPreferencesORAccountViewController alloc] initWithPreferences: _prefs];
            }
            [_accountBox setContentView: [_openRadarAccountViewController view]];
            break;
    }
}

// from NSTableViewDataSource protocol
- (NSInteger) numberOfRowsInTableView: (NSTableView *) tableView {
    return 2;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    /* Fetch (or create) a re-usable view */
    ANTPreferencesAccountCellView *result = [tableView makeViewWithIdentifier: @"AccountCell" owner:self];
    
    switch ((ANTPreferencesWindowAccountRow)row) {
        case ANTPreferencesWindowAccountRowAppleId:
            if ([_prefs appleID] != nil) {
                [result.textField setStringValue: [_prefs appleID]];
                [result.detailTextField setStringValue: NSLocalizedString(@"Apple ID", nil)];
                [result.imageView setImage: [NSImage imageNamed: NSImageNameMobileMe]];
            } else {
                [result.textField setStringValue: NSLocalizedString(@"(Inactive)", nil)];
            }
            break;
            
        case ANTPreferencesWindowAccountRowOpenRadar:
            [result.textField setStringValue: NSLocalizedString(@"Open Radar", nil)];
            [result.detailTextField setStringValue: NSLocalizedString(@"(Inactive)", nil)];
            [result.imageView setImage: [NSImage imageNamed: @"openradar_icon.pdf"]];
            break;
    }
    
    /* Configure and return the cell */
    return result;
}

@end
