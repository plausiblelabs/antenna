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

#import <Foundation/Foundation.h>
#import "ANTRadarSummaryResponse.h"
#import "ANTPreferences.h"

#import "ANTNetworkClientAuthResult.h"
#import "ANTNetworkClientAuthDelegate.h"

#import "ANTErrorDomain.h"

extern NSString *ANTNetworkClientDidChangeAuthState;

/**
 * Client authentication states.
 */
typedef NS_ENUM(NSUInteger, ANTNetworkClientAuthState) {
    /** Client is authenticated. */
    ANTNetworkClientAuthStateAuthenticated = 0,
    
    /** Client is authenticating. */
    ANTNetworkClientAuthStateAuthenticating = 1,
    
    /** Client is logging out. */
    ANTNetworkClientAuthStateLoggingOut = 2,
    
    /** Client is logged out. */
    ANTNetworkClientAuthStateLoggedOut = 3
};

@interface ANTNetworkClient : NSObject

+ (NSURL *) bugReporterURL;

- (instancetype) initWithAuthDelegate: (id<ANTNetworkClientAuthDelegate>) authDelegate;

- (void) login;
- (void) logoutWithCancelTicket: (PLCancelTicket *) ticket andCall: (void (^)(NSError *error)) callback;

- (void) requestSummariesForSection: (NSString *) sectionName completionHandler: (void (^)(NSArray *summaries, NSError *error)) handler;


/** Current client authentication state. */
@property(nonatomic, readonly) ANTNetworkClientAuthState authState;

@end
