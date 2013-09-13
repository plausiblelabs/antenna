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

#import "AntennaAppDelegate.h"

#import "ANTLoginWindowController.h"
#import "ANTPreferencesWindowController.h"
#import "ANTSummaryWindowController.h"
#import "AntennaApp.h"

#import "ANTPreferences.h"

@interface AntennaAppDelegate () <ANTNetworkClientAuthDelegate, LoginWindowControllerDelegate, AntennaAppDelegate>

@property(nonatomic, readonly) ANTPreferencesWindowController *preferencesWindowController;

@end

@implementation AntennaAppDelegate {
@private
    /** Application preferences */
    ANTPreferences *_preferences;
    
    /** Summary window controller */
    IBOutlet ANTSummaryWindowController *_summaryWindowController;

    /** The login window controller (nil if login is not pending). */
    ANTLoginWindowController *_loginWindowController;

    /** Preferences window controller (lazy loaded; nil if not yet instantiated). */
    ANTPreferencesWindowController *_prefsWindowController;
    
    /**
     * All pending authentication blocks; these should be dispatched when the login
     * window controller succeeds/fails.
     */
    NSMutableArray *_authCallbacks;
}

// from NSApplicationDelegate protocol; sent prior to window restoration.
- (void) applicationWillFinishLaunching: (NSNotification *) notification {
    /* Fetch preferences */
    _preferences = [[ANTPreferences alloc] init];
    
    /* Set up client */
    _networkClient = [[ANTNetworkClient alloc] initWithAuthDelegate: self];
    
    /* Configure authentication state */
    _authCallbacks = [NSMutableArray array];
}

// from NSApplicationDelegate protocol; sent after window restoration.
- (void) applicationDidFinishLaunching: (NSNotification *) aNotification {
    /* Wait for login, and then fire up our summary window */
    [[NSNotificationCenter defaultCenter] addObserverForName:  ANTNetworkClientDidChangeAuthState object: _networkClient queue: [NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        // XXX hack
        if (_networkClient.authState == ANTNetworkClientAuthStateAuthenticated)
            [_summaryWindowController showWindow: nil];
    }];
}

// from AntennaAppDelegate protocol
- (BOOL) restoreWindowWithIdentifier: (NSString *) identifier state: (NSCoder *) state completionHandler: (void (^)(NSWindow *, NSError *)) completionHandler {
    if ([identifier isEqual: [ANTPreferencesWindowController restorationIdentifier]]) {
        [self.preferencesWindowController restoreWindowState: state completionHandler: completionHandler];
        return YES;
    }
    return NO;
}

// Preferences menu item action
- (IBAction) openPreferences: (id) sender {
    [self.preferencesWindowController showWindow: nil];
}

// from ANTLoginWindowControllerDelegate protocol
- (void) loginWindowController: (ANTLoginWindowController *) sender didFinishWithToken: (NSString *) csrfToken {
    [_loginWindowController close];
    _loginWindowController = nil;

    ANTNetworkClientAuthResult *result = [[ANTNetworkClientAuthResult alloc] initWithCSRFToken: csrfToken];
    for (ANTNetworkClientAuthDelegateCallback cb in _authCallbacks) {
        cb(result, nil);
    }
}

// from ANTNetworkClientAuthDelegate protocol
- (void) networkClient: (ANTNetworkClient *) sender authRequiredWithCancelTicket: (PLCancelTicket *) ticket andCall: (ANTNetworkClientAuthDelegateCallback) callback {
    if (_loginWindowController == nil) {
        _loginWindowController = [[ANTLoginWindowController alloc] initWithPreferences: _preferences];
        _loginWindowController.delegate = self;
        [_loginWindowController start];
    }

    /* Register the callback block and the cancellation handler */
    void (^copied)(NSError *error) = [callback copy];
    [_authCallbacks addObject: copied];
    [ticket addCancelHandler: ^(PLCancelTicketReason reason) {
        [_authCallbacks removeObject: copied];
        
        /* If no more callbacks remain, cancel the login process */
        if ([_authCallbacks count] == 0) {
            _loginWindowController.delegate = nil;
            [_loginWindowController close];
            _loginWindowController = nil;
        }
    } dispatchContext: [PLGCDDispatchContext mainQueueContext]];
}

#pragma mark Properties

// property getter
- (ANTPreferencesWindowController *) preferencesWindowController {
    if (_prefsWindowController == nil)
        _prefsWindowController = [[ANTPreferencesWindowController alloc] initWithPreferences: _preferences];
        
        return _prefsWindowController;
}

@end
