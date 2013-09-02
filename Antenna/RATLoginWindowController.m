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

#import "RATLoginWindowController.h"
#import <WebKit/WebKit.h>

#import "RATNetworkClient.h"

@interface RATLoginWindowController ()

@end

@implementation RATLoginWindowController {
@private
    __weak IBOutlet WebView *_webView;

    BOOL _loginDone;
    BOOL _loginNotifyDone;
}

/**
 * Initialize a new window controller instance.
 */
- (id) init {
    if ((self = [super initWithWindowNibName: [self className] owner: self]) == nil)
        return nil;
    
    return self;
}

- (void) windowDidLoad {
    [super windowDidLoad];

    NSURLRequest *req = [NSURLRequest requestWithURL: [NSURL URLWithString: @"https://bugreport.apple.com"]];
    [[_webView mainFrame] loadRequest: req];
}

- (void) webView: (WebView *) sender didFinishLoadForFrame: (WebFrame *) frame {
    if (!_loginDone)
        return;
    
    if (_loginNotifyDone)
        return;
    
    _loginNotifyDone = YES;

    /* Try to fetch the CSRF token */
    NSString *csrfToken = [[_webView windowScriptObject] evaluateWebScript: @"$(\"#csrftokenPage\").val()"];
    
    /* Success! */
    [_delegate loginWindowController: self didFinishWithToken: csrfToken];
}

- (void) webView: (WebView *) sender resource: (id) identifier didReceiveResponse: (NSURLResponse *) response fromDataSource: (WebDataSource *) dataSource {
    if (_loginDone)
        return;

    if (![response isKindOfClass: [NSHTTPURLResponse class]])
        return;

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;

    /* Response must be a 200 (non-redirect) */
    if ([httpResponse statusCode] != 200)
        return;
    
    /* Response must be on the bugreport site */
    NSString *expectedHost = [[RATNetworkClient bugreporterURL] host];
    if (![[[httpResponse URL] host] isEqual: expectedHost])
        return;

    /* Mark login as complete */
    _loginDone = YES;

}

@end
