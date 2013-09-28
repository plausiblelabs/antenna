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
#import "ANTPreferences.h"

#import "ANTNetworkClientObserver.h"
#import "ANTNetworkClientAuthResult.h"
#import "ANTNetworkClientAuthDelegate.h"
#import "ANTNetworkClientAccount.h"

#import "ANTRadarSummariesResponse.h"
#import "ANTRadarSummaryResponse.h"
#import "ANTRadarResponse.h"

#import "ANTErrorDomain.h"

extern NSString *ANTNetworkClientFolderTypeAttention;
extern NSString *ANTNetworkClientFolderTypeOpen;
extern NSString *ANTNetworkClientFolderTypeClosed;
extern NSString *ANTNetworkClientFolderTypeArchive;
extern NSString *ANTNetworkClientFolderTypeDrafts;

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

- (void) addObserver: (id<ANTNetworkClientObserver>) observer
     dispatchContext: (id<PLDispatchContext>) context;

- (void) removeObserver: (id<ANTNetworkClientObserver>) observer;

- (void) loginWithAccount: (ANTNetworkClientAccount *) account
             cancelTicket: (PLCancelTicket *) ticket
          dispatchContext: (id<PLDispatchContext>) context
        completionHandler: (void (^)(NSError *error)) callback;

- (void) logoutWithCancelTicket: (PLCancelTicket *) ticket
                dispatchContext: (id<PLDispatchContext>) context
              completionHandler: (void (^)(NSError *error)) callback;

- (void) requestRadarWithId: (NSNumber *) radarId
               cancelTicket: (PLCancelTicket *) ticket
            dispatchContext: (id<PLDispatchContext>) context
          completionHandler: (void (^)(ANTRadarResponse *radar, NSError *error)) handler;


- (void) requestSummariesForSections: (NSArray *) sectionNames
                        maximumCount: (NSUInteger) maximumCount
                        cancelTicket: (PLCancelTicket *) ticket
                     dispatchContext: (id<PLDispatchContext>) context
                   completionHandler: (void (^)(NSArray *summaries, NSError *error)) handler;

- (void) requestSummariesForSection: (NSString *) sectionName
                       previousPage: (ANTRadarSummariesResponse *) previousPage
                       cancelTicket: (PLCancelTicket *) ticket
                    dispatchContext: (id<PLDispatchContext>) context
                  completionHandler: (void (^)(ANTRadarSummariesResponse *summaries, NSError *error)) handler;

/** Current client authentication state. */
@property(nonatomic, readonly) ANTNetworkClientAuthState authState;

@end
