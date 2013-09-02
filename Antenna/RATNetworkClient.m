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

#import "RATNetworkClient.h"
#import "RATLoginWindowController.h"

/**
 * Notification dispatched on successful login. The notification object will
 * be the authenticated network client instance.
 */
NSString *RATNetworkClientDidLoginNotification = @"RATNetworkClientDidLoginNotification";

@interface RATNetworkClient () <RATLoginWindowControllerDelegate>

@end

@implementation RATNetworkClient {
@private
    RATLoginWindowController *_loginWindowController;
    NSString *_csrfToken;
}

/**
 * Return the default bug reporter URL.
 */
+ (NSURL *) bugreporterURL {
    return [NSURL URLWithString: @"https://bugreport.apple.com"];
}

- (void) reportSummariesForSection: (NSString *) sectionName {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject: @{@"reportID" : sectionName, @"orderBy" : @"DateOriginated,Descending", @"rowStartString":@"1" }
                                                       options: 0
                                                         error: &error];

    NSURL *url = [NSURL URLWithString: @"/developer/problem/getSectionProblems" relativeToURL: [RATNetworkClient bugreporterURL]];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL: url];
    [req setHTTPMethod: @"POST"];
    [req setHTTPBody: jsonData];
    
    [req setValue: [[RATNetworkClient bugreporterURL] absoluteString] forHTTPHeaderField: @"Origin"];
    [req setValue: @"XMLHTTPRequest" forHTTPHeaderField: @"X-Requested-With"];
    [req setValue: @"application/json; charset=UTF-8" forHTTPHeaderField: @"Content-Type"];
    [req addValue: _csrfToken forHTTPHeaderField:@"csrftokencheck"];
    [req addValue: @"no-cache" forHTTPHeaderField: @"Cache-Control"];

    [req setCachePolicy: NSURLCacheStorageNotAllowed];
    [req setHTTPShouldHandleCookies: YES];

    [NSURLConnection sendAsynchronousRequest: req queue: [NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *error) {
        NSLog(@"Response is: %@", resp);
        NSLog(@"DATA: %@", [NSJSONSerialization JSONObjectWithData: data options:0 error:NULL]);
        NSLog(@"SDATA: %@", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);
        NSLog(@"%@", error);
    }];
}

/**
 * Issue a login request. This will display an embedded WebKit window.
 */
- (void) login {
    if (_loginWindowController == nil) {
        _loginWindowController = [[RATLoginWindowController alloc] init];
        _loginWindowController.delegate = self;
        [_loginWindowController showWindow: nil];
    }
}

// from RATLoginWindowControllerDelegate protocol
- (void) loginWindowController: (RATLoginWindowController *) sender didFinishWithToken: (NSString *) csrfToken {
    [_loginWindowController close];
    _loginWindowController = nil;
    _csrfToken = csrfToken;

    [[NSNotificationCenter defaultCenter] postNotificationName: RATNetworkClientDidLoginNotification object: self];
}

@end
