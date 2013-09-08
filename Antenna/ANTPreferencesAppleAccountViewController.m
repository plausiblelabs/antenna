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

#import "ANTPreferencesAppleAccountViewController.h"

@interface ANTPreferencesAppleAccountViewController () <NSTextFieldDelegate>

@end

/**
 * Manages the Apple account preferences view.
 */
@implementation ANTPreferencesAppleAccountViewController {
    /** Backing preferences */
    ANTPreferences *_prefs;
    
    /** Apple ID entry field. */
    __weak IBOutlet NSTextField *_loginField;

    /** Password entry field. */
    __weak IBOutlet NSSecureTextField *_passwordField;

    /** Sign in button */
    __weak IBOutlet NSButton *_signInButton;
}

/**
 * Initialize a new instance with @a preferences.
 *
 * @param preferences Application preferences.
 */
- (instancetype) initWithPreferences: (ANTPreferences *) preferences {
    if ((self = [super initWithNibName: [self className] bundle: [NSBundle bundleForClass: [self class]]]) == nil)
        return nil;
    
    _prefs = preferences;
    
    return self;
}

- (void) loadView {
    [super loadView];
    
    /* Configure the field defaults */
    if ([_prefs appleID] != nil)
        [_loginField setStringValue: [_prefs appleID]];
    else
        [_loginField setStringValue: @""];

    // TODO password lookup - we need a fixed URL we can use for password
    // retrieval from the keychain, rather than relying on the dynamically
    // redirected target of the web login.
}

// from NSControl informal protocol
- (void) controlTextDidChange: (NSNotification *) aNotification {
    if ([[_loginField stringValue] length] > 0 && [[_passwordField stringValue] length] > 0) {
        [_signInButton setEnabled: YES];
    } else {
        [_signInButton setEnabled: NO];
    }
}

- (IBAction) didPressForgotPasswordButton: (id) sender {
    // TODO
}

- (IBAction) didPressSignInButton: (id) sender {
    // TODO
}

@end
