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

#import "ANTNetworkClient.h"
#import "ANTCookieJar.h"

#import "NSObject+MAErrorReporting.h"

#import <Security/Security.h>
#import <WebKit/WebKit.h>

@interface ANTLoginWindowController ()

@end

@implementation ANTLoginWindowController {
@private
    /** User preferences. */
    ANTPreferences *_preferences;

    /** Backing web view */
    __weak IBOutlet WebView *_webView;
    
    /** Login panel */
    __weak IBOutlet NSPanel *_loginPanel;
    
    /** The account info to use for login. */
    ANTNetworkClientAccount *_account;

    /** The keychain item used for the last authentication attempt, if any. This will be nil
     * if authentication has never been attempted, or if no keychain item was used */
    EMKeychainItem *_lastAuthKeychainItem;
    
    /** Login panel username field. */
    __weak IBOutlet NSTextField *_loginUsernameField;

    /** Login panel password field. */
    __weak IBOutlet NSSecureTextField *_loginPasswordField;
        
    /** Login 'Save password' checkbox */
    __weak IBOutlet NSButton *_loginSavePasswordCheckbox;

    /** Login completed successfully. */
    BOOL _loginDone;
    
    /** Login notification sent to delegate */
    BOOL _loginNotifyDone;
    
    /** Attempted to auto-login once */
    BOOL _didAttemptAutoLogin;
}

/**
 * Initialize a new window controller instance.
 *
 * @param account The account to use for authentication, or nil if account details should be automatically fetched (either from the
 * current preferences, or by displaying a user dialog).
 * @param preferences The application preferences.
 */
- (id) initWithAccount: (ANTNetworkClientAccount *) account preferences: (ANTPreferences *) preferences {
    if ((self = [super initWithWindowNibName: [self className] owner: self]) == nil)
        return nil;
    
    _account = account;
    _preferences = preferences;
    _cookieJar = [ANTCookieJar new];

    return self;
}

- (void) dealloc {
    [[_webView mainFrame] stopLoading];
    _webView.frameLoadDelegate = nil;
    _webView.resourceLoadDelegate = nil;
}

/**
 * Start authentication; this will display UI as necessary.
 */
- (void) start {
    /* Force a window load; we keep the WebKit window hidden by default */
    [self window];
}

- (void) windowDidLoad {
    [super windowDidLoad];

    NSURLRequest *req = [NSURLRequest requestWithURL: [ANTNetworkClient bugReporterURL]];
    [[_webView mainFrame] loadRequest: req];
}

// from NSControl informal protocol
- (void) controlTextDidEndEditing: (NSNotification *) aNotification {
    if ([aNotification object] == _loginUsernameField) {
        [_preferences setAppleID: [_loginUsernameField stringValue]];
    }
}

// from NSControl informal protocol
- (void) controlDidBecomeFirstResponder:(NSNotification *)aNotification {
    if ([aNotification object] == _loginPasswordField && [[_loginPasswordField stringValue] length] == 0) {
        EMInternetKeychainItem *item = [_preferences appleKeychainItem];
        if (item != nil && item.password != nil) {
            [_loginPasswordField setStringValue: item.password];
        }
    }
}

// from WebResourceLoadDelegate protocol
- (NSURLRequest *) webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
    /* Configure a replacement */
    NSMutableURLRequest *replacement = [request mutableCopy];
    [replacement setHTTPShouldHandleCookies: NO];
    
    /* Extract and save all cookies from the redirect response, if any. */
    if (redirectResponse != nil && [redirectResponse isKindOfClass: [NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpRedirectResponse = (NSHTTPURLResponse *) redirectResponse;

        NSArray *cookies = [ANTCookieJar cookiesWithResponseHeaderFields: [httpRedirectResponse allHeaderFields] forURL: [httpRedirectResponse URL]];
        for (NSHTTPCookie *cookie in cookies)
            [_cookieJar setCookie: cookie];
    }

    /* Insert our cookies */
    NSArray *cookies = [_cookieJar cookiesForURL: [request URL]];
    NSDictionary *fields = [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
    for (NSString *name in fields)
        [replacement addValue: fields[name] forHTTPHeaderField: name];

    return replacement;
}

// from WebResourceLoadDelegate protocol
- (void) webView: (WebView *) sender resource: (id) identifier didReceiveResponse: (NSURLResponse *) response fromDataSource: (WebDataSource *) dataSource {
    if (![response isKindOfClass: [NSHTTPURLResponse class]])
        return;
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;

    /* Extract and save all cookies */
    NSArray *cookies = [ANTCookieJar cookiesWithResponseHeaderFields: [httpResponse allHeaderFields] forURL: [response URL]];
    for (NSHTTPCookie *cookie in cookies)
        [_cookieJar setCookie: cookie];

    /* Skip response handling if we've already logged in, or if we haven't yet attempted to log in */
    if (_loginDone)
        return;
    
    if (!_didAttemptAutoLogin)
        return;

    /* Response must be a 200 (non-redirect) */
    if ([httpResponse statusCode] != 200)
        return;
    
    /* Response must be on the bugreport site */
    NSString *expectedHost = [[ANTNetworkClient bugReporterURL] host];
    if (![[[httpResponse URL] host] isEqual: expectedHost]) {
        [self failWithInvalidPageError];
        _didAttemptAutoLogin = NO;
        return;
    }

    /* Mark login as complete */
    _loginDone = YES;

}

/**
 * Inform the delegate of failure.
 */
- (void) failWithInvalidPageError {
    NSError *error = [NSError pl_errorWithDomain: ANTErrorDomain
                                            code: ANTErrorAuthenticationFailed
                            localizedDescription: NSLocalizedString(@"Web-based authentication failed", nil)
                          localizedFailureReason: NSLocalizedString(@"The web interface returned an unexpected page", nil)
                                 underlyingError: nil
                                        userInfo: nil];
    
    _loginNotifyDone = YES;
    [_delegate loginWindowController: self didFailWithError: error];
}

// Login button pressed
- (IBAction) didSubmitLoginDialog: (id) sender {
    /* Fetch the form elements */
    NSURL *loginURL;
    DOMHTMLInputElement *accountElement;
    DOMHTMLInputElement *passwordElement;
    
    if (![self findAccountElement: &accountElement passwordElement: &passwordElement loginURL: &loginURL]) {
        NSLog(@"Could not find required elements, giving up on auto-auth");
        [self failWithInvalidPageError];
        return;
    }

    /* Configure and submit the form */
    _didAttemptAutoLogin = YES;

    [accountElement setAttribute: @"value" value: [_loginUsernameField stringValue]];
    [passwordElement setAttribute: @"value" value: [_loginPasswordField stringValue]];
    [[passwordElement form] submit];

    /* Dismiss the sheet */
    [NSApp endSheet: _loginPanel];
    [_loginPanel orderOut: self];
}

// Login cancel button pressed.
- (IBAction) didCancelLoginDialog: (id) sender {
    [NSApp endSheet: _loginPanel];
    [_loginPanel orderOut: self];

    /* Login failed; pop up the web browser window */
    [self showWindow: nil];
}

/**
 * @internal
 *
 * Validate, find, and return the username and password elements from the login form, if available.
 *
 * This method will only return YES if:
 * - The page was loaded via HTTPS.
 * - The domain is .apple.com
 * - The username and password fields can be found, and match the expected IDs, names, and types.
 *
 * @param accountElement The account DOM element.
 * @param passwordElement The password DOM element.
 * @param loginURL The current page's URL.
 *
 * @return Returns YES on success, or NO if the page can not be validated, or the required elements can not be found.
 */
- (BOOL) findAccountElement: (DOMHTMLInputElement **) accountElement passwordElement: (DOMHTMLInputElement **) passwordElement loginURL: (NSURL **) loginURL {
    NSURL *frameURL = [NSURL URLWithString: [_webView mainFrameURL]];
    
    /* The mechanism must be SSL */
    if (![[frameURL scheme] isEqual: @"https"]) {
        NSLog(@"Skipping auto-auth for non-SSL URL: %@", frameURL);
        return NO;
    }
    
    /* The address must be .apple.com */
    NSRange appleDomainRange = [[frameURL host] rangeOfString: @"apple.com"];
    if (appleDomainRange.location == NSNotFound || NSMaxRange(appleDomainRange) != [[frameURL host] length]) {
        NSLog(@"Skipping auto-auth for non-apple URL: %@", frameURL);
        return NO;
    }
    
    /* Find the account name field */
    DOMDocument *doc = [[_webView mainFrame] DOMDocument];
    {
        DOMElement *elem = [doc getElementById: @"accountname"];
        if (elem == nil) {
            NSLog(@"Skipping auto-auth; could not find 'accountname' element");
            return NO;
        }
        
        /* Verify the type */
        if (![elem isKindOfClass: [DOMHTMLInputElement class]]) {
            NSLog(@"Skipping auto-auth; 'accountname' is not of expected type (%@)", elem);
            return NO;
        }
        
        *accountElement = (DOMHTMLInputElement *) elem;
        if ([[*accountElement getAttribute: @"type"] caseInsensitiveCompare: @"text"] != NSOrderedSame) {
            NSLog(@"Skipping auto-auth; 'accountname' input field is not of expected type (type=%@)", [*accountElement getAttribute: @"type"]);
        }
        
        /* Verify the name */
        if (![[*accountElement getAttribute: @"name"] isEqual: @"appleId"]) {
            NSLog(@"Skipping auto-auth; 'accountname' element does not have expected name: %@", [*accountElement getAttribute: @"name"]);
            return NO;
        }
        
    }
    
    /* Find the password field */
    {
        DOMElement *elem = [doc getElementById: @"accountpassword"];
        if (elem == nil) {
            NSLog(@"Skipping auto-auth; could not find 'accountpassword' element");
            return NO;
        }
        
        /* Verify the type */
        if (![elem isKindOfClass: [DOMHTMLInputElement class]]) {
            NSLog(@"Skipping auto-auth; 'accountpassword' is not of expected type (%@)", elem);
            return NO;
        }
        
        *passwordElement = (DOMHTMLInputElement *) elem;
        if ([[*passwordElement getAttribute: @"type"] caseInsensitiveCompare: @"password"] != NSOrderedSame) {
            NSLog(@"Skipping auto-auth; 'accountpassword' input field is not of expected type (type=%@)", [*passwordElement getAttribute: @"type"]);
            return NO;
        }
        
        /* Verify the name */
        if (![[*passwordElement getAttribute: @"name"] isEqual: @"accountPassword"]) {
            NSLog(@"Skipping auto-auth; 'accountpassword' element does not have expected name: %@", [*passwordElement getAttribute: @"name"]);
            return NO;
        }
    }

    *loginURL = frameURL;
    return YES;
}

/* Try to auto-fill the login form; we perform sanity checks here to ensure we're not just POST'ing the
 * password anywhere willy-nilly */
- (void) tryAutofillingLoginForm {
    /* Don't keep retrying if it fails the first time. */
    if (_didAttemptAutoLogin)
        return;
    
    /* Verify that this is the correct page, and fetch the account/password elements */
    DOMHTMLInputElement *accountElement;
    DOMHTMLInputElement *passwordElement;
    NSURL *loginURL;
    
    if (![self findAccountElement: &accountElement passwordElement: &passwordElement loginURL: &loginURL]) {
        NSLog(@"Could not find required elements, giving up on auto-auth");
        return;
    }

    /* Populate the form */
    [_loginUsernameField setStringValue: _account.username];
    [_loginPasswordField setStringValue: _account.password];
    [self didSubmitLoginDialog: self];
}

// from NSWindowDelegate protocol
- (void) windowWillClose: (NSNotification *) notification {
    if (_loginNotifyDone)
        return;

    _loginNotifyDone = YES;
    NSError *error = [NSError pl_errorWithDomain: ANTErrorDomain
                                            code: ANTErrorRequestCancelled
                            localizedDescription: NSLocalizedString(@"Sign in failed.", nil)
                          localizedFailureReason: NSLocalizedString(@"The sign in window was closed", nil)
                                 underlyingError: nil
                                        userInfo: nil];
    [_delegate loginWindowController: self didFailWithError: error];
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
    
    /* Try to fetch the CSRF token */
    NSString *csrfToken = [[_webView windowScriptObject] evaluateWebScript: @"$(\"#csrftokenPage\").val()"];
    if ([csrfToken isKindOfClass: [WebUndefined class]]) {
        /* Display the web view to simplify debugging. */
        NSLog(@"Missing CSRF token on page!");
        [self showWindow: nil];
        return;
    }
    
    _loginNotifyDone = YES;
    
    /*
     * If requested in the login dialog, save the password. This isn't done if
     * a username/password was supplied via _account, as it's assumed that
     * the requisite handling is done externally.
     */
    if (_account == nil &&
        [_loginSavePasswordCheckbox state] == NSOnState &&
        [_loginUsernameField stringValue] != nil &&
        [_loginPasswordField stringValue] != nil)
    {
        /* Try to update the existing keychain item,if necessary. */
        NSString *accountName = [_loginUsernameField stringValue];
        NSString *password = [_loginPasswordField stringValue];
        
        if (_lastAuthKeychainItem != nil && [_lastAuthKeychainItem.username isEqual: accountName]) {
            if (![_lastAuthKeychainItem.password isEqual: password]) {
                _lastAuthKeychainItem.password = password;
            }
        } else {
            /* No item matched -- create a new item */
            [_preferences addAppleKeychainItemWithUsername:accountName password:password];
        }
        
        /* Update the preferred Apple ID */
        [_preferences setAppleID: accountName];
    }
    
    /* Success! */
    [_delegate loginWindowController: self didFinishWithToken: csrfToken];
}

@end
