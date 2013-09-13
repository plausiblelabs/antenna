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
#import "EMKeychainItem.h"
#import "ANTSecureTextField.h"

@interface ANTPreferencesAppleAccountViewController () <NSTextFieldDelegate>

@end

/**
 * Manages the Apple account preferences view.
 */
@implementation ANTPreferencesAppleAccountViewController {
    /** ANT network client */
    ANTNetworkClient *_client;

    /** Backing preferences */
    ANTPreferences *_prefs;
    
    /** Apple ID entry field. */
    __weak IBOutlet NSTextField *_loginField;

    /** Password entry field. */
    __weak IBOutlet ANTSecureTextField *_passwordField;

    /** Sign in button */
    __weak IBOutlet NSButton *_signInButton;
    
    /** Forgot password button */
    __weak IBOutlet NSButton *_forgotPasswordButton;
    
    /** Log in spinner */
    __weak IBOutlet NSProgressIndicator *_spinner;

    /** True if currently logging out */
    BOOL _loggingOut;
}

/**
 * Initialize a new instance with @a preferences.
 *
 * @param client The backing radar network client.
 * @param preferences Application preferences.
 */
- (instancetype) initWithClient: (ANTNetworkClient *) client preferences: (ANTPreferences *) preferences {
    if ((self = [super initWithNibName: [self className] bundle: [NSBundle bundleForClass: [self class]]]) == nil)
        return nil;

    _client = client;
    _prefs = preferences;

    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(updateAuthState:) name: ANTNetworkClientDidChangeAuthState object: _client];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(updateAuthState:) name: ANTPreferencesDidChangeNotification object: _prefs];
    
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) loadView {
    [super loadView];
    
    [self updateAuthState: nil];
}

- (void) tryEnableSignOnButton {
    if ([[_loginField stringValue] length] > 0 && [[_passwordField stringValue] length] > 0) {
        [_signInButton setEnabled: YES];
    } else {
        [_signInButton setEnabled: NO];
    }
}

- (void) updateAuthState: (NSNotification *) notification {
    /* Configure the UI state */
    switch (_client.authState) {
        case ANTNetworkClientAuthStateLoggedOut:
            /* Only reset the fields if they're just now being set as enabled. */
            if (_loggingOut) {
                [_loginField setStringValue: @""];
                [_passwordField setStringValue: @""];
                _loggingOut = NO;
            }

            [_loginField setEnabled: YES];
            [_passwordField setEnabled: YES];
            [self tryEnableSignOnButton];

            [_signInButton setTitle: NSLocalizedString(@"Sign In", nil)];
            [_forgotPasswordButton setHidden: NO];
            [_spinner stopAnimation: self];
            break;
            
        case ANTNetworkClientAuthStateAuthenticating:
            [_loginField setEnabled: NO];
            [_passwordField setEnabled: NO];

            [_signInButton setTitle: NSLocalizedString(@"Signing In", nil)];
            [_signInButton setEnabled: NO];
            [_forgotPasswordButton setHidden: YES];
            [_spinner startAnimation: self];
            break;
            
        case ANTNetworkClientAuthStateLoggingOut:
            _loggingOut = YES;
            [_loginField setEnabled: NO];
            [_passwordField setEnabled: NO];
            
            [_signInButton setTitle: NSLocalizedString(@"Signing Out", nil)];
            [_signInButton setEnabled: NO];
            [_forgotPasswordButton setHidden: YES];
            [_spinner startAnimation: self];
            break;
            
        case ANTNetworkClientAuthStateAuthenticated: {
            EMInternetKeychainItem *item = [_prefs appleKeychainItem];
            if (item != nil && item.username != nil)
                [_loginField setStringValue: item.username];
            
            if (item != nil && item.password != nil)
                [_passwordField setStringValue: item.password];
            
            [_loginField setEnabled: NO];
            [_passwordField setEnabled: NO];

            [_signInButton setTitle: NSLocalizedString(@"Sign Out", nil)];
            [_signInButton setEnabled: YES];
            [_forgotPasswordButton setHidden: YES];
            [_spinner stopAnimation: self];
            break;
        }
    }
}

// from NSControl informal protocol
- (void) controlTextDidChange: (NSNotification *) aNotification {
    [self tryEnableSignOnButton];
}

// from NSControl informal protocol
- (void) controlTextDidEndEditing: (NSNotification *) aNotification {
    if ([aNotification object] == _loginField) {
        [_prefs setAppleID: [_loginField stringValue]];
    }
}

// from NSControl informal protocol
- (void) controlDidBecomeFirstResponder:(NSNotification *)aNotification {
    if ([aNotification object] == _passwordField && [[_passwordField stringValue] length] == 0) {
        EMInternetKeychainItem *item = [_prefs appleKeychainItem];
        if (item != nil && item.password != nil) {
            [_passwordField setStringValue: item.password];
            [self tryEnableSignOnButton];
        }
    }
}

- (IBAction) didPressForgotPasswordButton: (id) sender {
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"https://iforgot.apple.com/password/verify/appleid"]];
}

// Delegate method for a failed login.
- (void) loginFailedAlertDidEnd: (NSAlert *) alert returnCode: (NSInteger) returnCode contextInfo: (void *) contextInfo {
    /* After displaying the error, refocus on the password field. */
    [_passwordField becomeFirstResponder];
}

// Delegate method for a failed log out.
- (void) logoutFailedAlertDidEnd: (NSAlert *) alert returnCode: (NSInteger) returnCode contextInfo: (void *) contextInfo {
}

- (IBAction) didPressSignInButton: (id) sender {
    PLCancelTicketSource *ticketSource = [PLCancelTicketSource new];
    
    switch (_client.authState) {
        case ANTNetworkClientAuthStateLoggedOut: {
            ANTNetworkClientAccount *account = [[ANTNetworkClientAccount alloc] initWithUsername: _loginField.stringValue password: _passwordField.stringValue];
            [_client loginWithAccount: account
                         cancelTicket: ticketSource.ticket
                              andCall: ^(NSError *error)
            {
                if (error != nil) {
                    [[NSAlert alertWithError: error] beginSheetModalForWindow: self.view.window modalDelegate: self didEndSelector: @selector(loginFailedAlertDidEnd:returnCode:contextInfo:) contextInfo: nil];
                    return;
                }

                /* Update user configuration on success */
                [_prefs setAppleID: account.username];
                if ([_prefs appleKeychainItem] != nil) {
                    [_prefs appleKeychainItem].password = account.password;
                } else {
                    [_prefs addAppleKeychainItemWithUsername: account.username password: account.password];
                }
            }];
            break;
        }

        case ANTNetworkClientAuthStateAuthenticating:
            break;
            
        case ANTNetworkClientAuthStateLoggingOut:
            break;
            
        case ANTNetworkClientAuthStateAuthenticated:
            [_client logoutWithCancelTicket: ticketSource.ticket andCall:^(NSError *error) {
                if (error != nil) {
                    [[NSAlert alertWithError: error] beginSheetModalForWindow: self.view.window modalDelegate: self didEndSelector: @selector(logoutFailedAlertDidEnd:returnCode:contextInfo:) contextInfo: nil];
                    return;
                } else {
                    [_prefs setAppleID: nil];
                }
            }];
            break;
    }
}

@end
