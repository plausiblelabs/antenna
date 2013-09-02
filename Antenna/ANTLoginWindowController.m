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
#import "NSObject+MAErrorReporting.h"

#import <Security/Security.h>
#import <WebKit/WebKit.h>

@interface ANTLoginWindowController ()

@end

@implementation ANTLoginWindowController {
@private
    /** Backing web view */
    __weak IBOutlet WebView *_webView;
    
    /** Login panel */
    __weak IBOutlet NSPanel *_loginPanel;
    
    /** The URL of the page on which we last attempted authentication. This will be nil
     * if authentication has never been attempted. */
    NSURL *_lastAuthURL;
    
    /** Login panel username field. */
    __weak IBOutlet NSTextField *_loginUsernameField;

    /** Login panel password field. */
    __weak IBOutlet NSSecureTextField *_loginPasswordField;
    
    /** Login explanatory message label */
    __weak IBOutlet NSTextField *_loginMessageLabel;
    
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

// Login sheet delegate
- (void) didEndLoginSheet: (NSWindow *) sheet returnCode: (NSInteger) returnCode contextInfo: (void *) contextInfo {
    [sheet orderOut: self];
}

// Login button pressed
- (IBAction) didSubmitLoginDialog: (id) sender {
    /* Fetch the form elements */
    NSURL *loginURL;
    DOMHTMLInputElement *accountElement;
    DOMHTMLInputElement *passwordElement;
    
    if (![self findAccountElement: &accountElement passwordElement: &passwordElement loginURL: &loginURL]) {
        NSLog(@"Could not find required elements, giving up on auto-auth");
        return;
    }

    /* Configure and submit the form */
    _didAttemptAutoLogin = YES;
    _lastAuthURL = loginURL;

    [accountElement setAttribute: @"value" value: [_loginUsernameField stringValue]];
    [passwordElement setAttribute: @"value" value: [_loginPasswordField stringValue]];
    [[passwordElement form] submit];

    /* Dismiss the sheet */
    [NSApp endSheet: _loginPanel];
}

// Login cancel button pressed.
- (IBAction) didCancelLoginDialog: (id) sender {
    [NSApp endSheet: _loginPanel];
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

    /* Try fetching the password from the keychain */
    // TODO - Lift out into a generic preferences API
    NSString *accountName = [[NSUserDefaults standardUserDefaults] stringForKey: @"ANTLoginUserName"];
    if (accountName == nil)
        accountName = [accountElement getAttribute: @"value"];

    /* Fetch the target URL */
    NSURL *url = [NSURL URLWithString: [_webView mainFrameURL]];
    
    /* The scheme is validated in -findAccountElement:passwordElement:, but we double-check here */
    NSAssert([[url scheme] isEqual: @"https"], @"Scheme must be HTTPS for kSecProtocolTypeHTTPS");

    NSString *password = nil;
    if (accountName != nil) {
        UInt32 passwordLength;
        void *passwordData;
        OSStatus status;
        status = SecKeychainFindInternetPassword(NULL,
                                                 (UInt32) strlen([[url host] UTF8String]),
                                                 [[url host] UTF8String],
                                                 0,
                                                 NULL,
                                                 (UInt32) strlen([accountName UTF8String]),
                                                 [accountName UTF8String],
                                                 (UInt32) strlen([[url path] UTF8String]),
                                                 [[url path] UTF8String],
                                                 [[url port] integerValue],
                                                 kSecProtocolTypeHTTPS,
                                                 kSecAuthenticationTypeAny,
                                                 &passwordLength,
                                                 &passwordData,
                                                 NULL);
        if (status == noErr) {
            password = [[NSString alloc] initWithBytes: passwordData length: passwordLength encoding: NSUTF8StringEncoding];
            SecKeychainItemFreeContent(NULL, passwordData);
        } else {
            NSLog(@"SecKeychainFindInternetPassword() failed with status=%d", status);
        }
    }
    
    /* Display login dialog */
    NSString *message = [NSString stringWithFormat: NSLocalizedString(@"Your password will be submitted securely via %@.", @"Login message"), [_webView mainFrameURL]];
    [_loginMessageLabel setStringValue: message];

    /* Set up defaults */
    if (accountName != nil)
        [_loginUsernameField setStringValue: accountName];

    if (password != nil)
        [_loginPasswordField setStringValue: password];

    [NSApp beginSheet: _loginPanel modalForWindow: self.window modalDelegate: self didEndSelector:@selector(didEndLoginSheet:returnCode:contextInfo:) contextInfo: nil];
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
    
    /* If requested, save the password */
    if ([_loginSavePasswordCheckbox state] == NSOnState &&
        [_loginUsernameField stringValue] != nil &&
        [_loginPasswordField stringValue] != nil &&
        _lastAuthURL != nil)
    {
        OSStatus status;
        
        NSString *accountName = [_loginUsernameField stringValue];
        NSString *password = [_loginPasswordField stringValue];
        const char *passwordData = [password UTF8String];
        UInt32 passwordLength = (UInt32) strlen(passwordData);
    
        status = SecKeychainAddInternetPassword(NULL,
                                                (UInt32) strlen([[_lastAuthURL host] UTF8String]),
                                                [[_lastAuthURL host] UTF8String],
                                                0,
                                                NULL,
                                                (UInt32) strlen([accountName UTF8String]),
                                                [accountName UTF8String],
                                                (UInt32) strlen([[_lastAuthURL path] UTF8String]),
                                                [[_lastAuthURL path] UTF8String],
                                                [[_lastAuthURL port] integerValue],
                                                kSecProtocolTypeHTTPS,
                                                kSecAuthenticationTypeAny,
                                                passwordLength,
                                                passwordData,
                                                NULL);
        if (status != noErr)
            NSLog(@"SecKeychainAddInternetPassword() failed with status=%d", status);
    }
    
    /* Success! */
    [_delegate loginWindowController: self didFinishWithToken: csrfToken];
}

@end
