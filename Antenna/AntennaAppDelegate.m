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
#import "ANTSummaryWindowController.h"
#import "ANTPreferences.h"

#import "ANTLoginWindowController.h"

@interface AntennaAppDelegate () <ANTNetworkClientAuthDelegate, RATLoginWindowControllerDelegate>
@end

@implementation AntennaAppDelegate {
@private
    /** Application preferences */
    ANTPreferences *_preferences;

    /** Summary window controller */
    IBOutlet ANTSummaryWindowController *_summaryWindowController;

    /** The login window controller (nil if login is not pending). */
    ANTLoginWindowController *_loginWindowController;
    
    /**
     * All pending authentication blocks; these should be dispatched when the login
     * window controller succeeds/fails.
     */
    NSMutableArray *_authCallbacks;
}

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification {
    /* Configure authentication state */
    _authCallbacks = [NSMutableArray array];

    /* Fetch preferences */
    _preferences = [[ANTPreferences alloc] init];

    /* Set up client and start login */
    _networkClient = [[ANTNetworkClient alloc] initWithPreferences: _preferences];
    [_networkClient login];

    /* Wait for completion, and then fire up our summary window */
    [[NSNotificationCenter defaultCenter] addObserverForName:  RATNetworkClientDidLoginNotification object: _networkClient queue: [NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [_summaryWindowController showWindow: nil];
    }];
}

// from ANTLoginWindowControllerDelegate protocol
- (void) loginWindowController: (ANTLoginWindowController *) sender didFinishWithToken: (NSString *) csrfToken {
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
        [_loginWindowController showWindow: nil];
    }

    /* Register the callback block and the cancellation handler */
    void (^copied)(NSError *error) = [callback copy];
    [_authCallbacks addObject: copied];
    [ticket addCancelHandler: ^(PLCancelTicketReason reason) {
        [_authCallbacks removeObject: copied];
        
        /* If no more callbacks remain, cancel the login process */
        if ([_authCallbacks count] == 0) {
            // TODO - dismiss the auth window
        }
    } dispatchContext: [PLGCDDispatchContext mainQueueContext]];
}

@end
