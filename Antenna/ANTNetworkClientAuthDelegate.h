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
#import <PLFoundation/PLFoundation.h>

#import "ANTNetworkClientAuthResult.h"
#import "ANTNetworkClientAccount.h"

@class ANTNetworkClient;

/**
 * Authentication callback.
 *
 * @param result The authentication result, or nil if an error occured.
 * @param error On failure, an error in the ANTErrorDomain, or nil on success.
 */
typedef void (^ANTNetworkClientAuthDelegateCallback)(ANTNetworkClientAuthResult *result, NSError *error);

/**
 * The ANTNetworkClientAuthDelegate protocol describes methods that must be implemented by ANTNetworkClient
 * authentication delegates.
 *
 * The Radar Web UI utilizes a web-based SSO sign-in system, coupled with JavaScript and HTML
 * delivery of session information, including session cookies, a CSRF token, and other 
 * elements that must be extracted for use by future network calls.
 *
 * It is the responsibility of the ANTNetworkClientAuthDelegate to implement UI and platform-specific (eg, WebView, UIWebView)
 * browser integration as necessary to implement client authentication.
 */
@protocol ANTNetworkClientAuthDelegate <NSObject>

/**
 * Authenticate the user and call @a callback.
 *
 * @param sender The requesting network client.
 * @param account The account to use for authentication, or nil if the authentiation delegate is expected
 * to provide the account info.
 *
 * @param ticket The cancellation ticket for the request.
 * @param callback The block to be called upon request completion.  
 *
 * @note Any cookies set in the authentication process should be made available via the global
 * NSHTTPCookieStorage instance. This requirement is due to the constraints of the NSURLConnection
 * class; there exists no mechanism by which we can designate a different NSHTTPCookieStorage instance
 * for use by an NSURLConnection request. This requirement may be modified in the future.
 */
- (void) networkClient: (ANTNetworkClient *) sender authRequiredWithAccount: (ANTNetworkClientAccount *) account cancelTicket: (PLCancelTicket *) ticket andCall: (ANTNetworkClientAuthDelegateCallback) callback;




@end
