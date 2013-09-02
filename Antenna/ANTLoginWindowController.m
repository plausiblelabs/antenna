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

#import "ANTLoginWindowController.h"
#import <WebKit/WebKit.h>

#import "ANTNetworkClient.h"
#import "NSObject+MAErrorReporting.h"

@interface ANTLoginWindowController ()

@end

@implementation ANTLoginWindowController {
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

/* Try to auto-fill the login form; we perform sanity checks here to ensure we're not just POST'ing the
 * password anywhere willy-nilly */
- (void) tryAutofillingLoginForm {
    NSURL *frameURL = [NSURL URLWithString: [_webView mainFrameURL]];
    
    /* The mechanism must be SSL */
    if (![[frameURL scheme] isEqual: @"https"]) {
        NSLog(@"Skipping auto-auth for non-SSL URL: %@", frameURL);
        return;
    }

    /* The address must be .apple.com */
    NSRange appleDomainRange = [[frameURL host] rangeOfString: @"apple.com"];
    if (appleDomainRange.location == NSNotFound || NSMaxRange(appleDomainRange) != [[frameURL host] length]) {
        NSLog(@"Skipping auto-auth for non-apple URL: %@", frameURL);
        return;
    }
    
    /* Find the account name field */
    DOMDocument *doc = [[_webView mainFrame] DOMDocument];
    {
        DOMElement *elem = [doc getElementById: @"accountname"];
        if (elem == nil) {
            NSLog(@"Skipping auto-auth; could not find 'accountname' element");
            return;
        }
            
        /* Verify the type */
        if (![elem isKindOfClass: [DOMHTMLInputElement class]]) {
            NSLog(@"Skipping auto-auth; 'accountname' is not of expected type (%@)", elem);
            return;
        }
        
        DOMHTMLInputElement *accountElement = (DOMHTMLInputElement *) elem;
        if ([[accountElement getAttribute: @"type"] caseInsensitiveCompare: @"text"] != NSOrderedSame) {
            NSLog(@"Skipping auto-auth; 'accountname' input field is not of expected type (type=%@)", [accountElement getAttribute: @"type"]);
        }
        
        /* Verify the name */
        if (![[accountElement getAttribute: @"name"] isEqual: @"appleId"]) {
            NSLog(@"Skipping auto-auth; 'accountname' element does not have expected name: %@", [accountElement getAttribute: @"name"]);
            return;
        }
        
        /* Set the value */
        [accountElement setAttribute: @"value" value: @"anaccount@example.org"];        
    }
    
    /* Find the password field */
    {
        DOMElement *elem = [doc getElementById: @"accountpassword"];
        if (elem == nil) {
            NSLog(@"Skipping auto-auth; could not find 'accountpassword' element");
            return;
        }
        
        /* Verify the type */
        if (![elem isKindOfClass: [DOMHTMLInputElement class]]) {
            NSLog(@"Skipping auto-auth; 'accountpassword' is not of expected type (%@)", elem);
            return;
        }
        
        DOMHTMLInputElement *passwordElement = (DOMHTMLInputElement *) elem;
        if ([[passwordElement getAttribute: @"type"] caseInsensitiveCompare: @"password"] != NSOrderedSame) {
            NSLog(@"Skipping auto-auth; 'accountpassword' input field is not of expected type (type=%@)", [passwordElement getAttribute: @"type"]);
        }
        
        /* Verify the name */
        if (![[passwordElement getAttribute: @"name"] isEqual: @"accountPassword"]) {
            NSLog(@"Skipping auto-auth; 'accountpassword' element does not have expected name: %@", [passwordElement getAttribute: @"name"]);
            return;
        }
        
        /* Set the value */
        [passwordElement setAttribute: @"value" value: @"password"];
        
        /* Submit! */
        // [[accountElement form] submit];
    }
}

- (void) webView: (WebView *) sender didFinishLoadForFrame: (WebFrame *) frame {
    /* Check for a login form. */
    if (!_loginDone) {
        [self tryAutofillingLoginForm];
        return;
    }

    /* If login notification is complete, there's nothing to check here */
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
    NSString *expectedHost = [[ANTNetworkClient bugreporterURL] host];
    if (![[[httpResponse URL] host] isEqual: expectedHost])
        return;

    /* Mark login as complete */
    _loginDone = YES;

}

@end
