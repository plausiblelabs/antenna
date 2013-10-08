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

#import <XCTest/XCTest.h>
#import "ANTCookieJar.h"

@interface ANTCookieJarTests : XCTestCase

@end

@implementation ANTCookieJarTests

/**
 * Tests both cookiesWithResponseHeaderFields:forURL: and validateCookie:forURL:
 */
- (void) testParseAndValidateCookie {
    /* Try parsing a @a cookie for @a url. If 'expectedDomain' is nil, verify that the cookie is discarded; otherwise, we verify that the cookie's
     * domain matches the provided value. */
    void (^TestCookie)(NSString *cookie, NSString *url, NSString *expectedDomain) = ^(NSString *cookie, NSString *url, NSString *expectedDomain) {
        NSArray *cookies = [ANTCookieJar cookiesWithResponseHeaderFields: @{ @"Set-Cookie": cookie } forURL: [NSURL URLWithString: url]];
        if (expectedDomain == nil) {
            XCTAssertEqual([cookies count], (NSUInteger) 0, @"No cookies should have been parsed for '%@': %@", cookie, cookies);
            return;
        }
        
        XCTAssertEqual([cookies count], (NSUInteger) 1, @"No cookies were parsed for %@@%@: %@", cookie, url, cookies);
        if (cookies.count == 0)
            return;

        NSHTTPCookie *nscookie = [cookies objectAtIndex: 0];
        XCTAssertEqualObjects(nscookie.domain, expectedDomain, @"The expected cookie domain was not returned for %@@%@", cookie, url);
    };
    
    /* IP addresses */
    TestCookie(@"n=v;domain=.example.org", @"http://[127.0.0.1]", @"127.0.0.1");
    TestCookie(@"n=v;domain=.example.org", @"http://127.0.0.1", @"127.0.0.1");
    
    /* Exact match. Note that NSHTTPCookie inserts a '.' prefix by default. */
    TestCookie(@"n=v;domain=www.example.org", @"http://www.example.org", @".www.example.org");

    /* Domain handling */
    TestCookie(@"n=v;domain=.example.org", @"http://www.example.org", @".example.org");
    TestCookie(@"n=v;domain=.org", @"http://www.example.org", @"www.example.org");
    
    // XXX: If the ruleset is modified to remove *.uk, or parliament.uk is no longer
    // excepted, the wildcard tests will begin to fail

    /* Wildcard handling */
    TestCookie(@"n=v;domain=.wildcard.uk", @"http://host.wildcard.uk", @"host.wildcard.uk");
    
    /* Wildcard exception handling */
    TestCookie(@"n=v;domain=.parliament.uk", @"http://host.parliament.uk", @".parliament.uk");

    /* Unknown TLD handling */
    TestCookie(@"n=v;domain=.domain.invaltld", @"http://host.domain.invaltld", @"host.domain.invaltld");

}

- (void) testSetDeleteCookie {
    /* Test set */
    ANTCookieJar *jar = [ANTCookieJar new];
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties: @{
        NSHTTPCookieDomain : @".example.org",
        NSHTTPCookieSecure : @(YES),
        NSHTTPCookieName : @"peanut",
        NSHTTPCookiePath : @"/path",
        NSHTTPCookieValue : @"val"
    }];
    XCTAssertNotNil(cookie, @"Failed to instantiate a cookie");
    [jar setCookie: cookie];

    XCTAssertEqual([[jar cookiesForURL: [NSURL URLWithString: @"https://example.org/path"]] count], (NSUInteger) 1, @"Cookie not found");
    
    /* Test deletion */
    [jar deleteCookie: cookie];
    XCTAssertEqual([[jar cookiesForURL: [NSURL URLWithString: @"https://example.org/path"]] count], (NSUInteger) 0, @"Cookie not deleted");
}

- (void) testCopy {
    /* Test set */
    ANTCookieJar *jar = [ANTCookieJar new];
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties: @{
                                                                 NSHTTPCookieDomain : @".example.org",
                                                                 NSHTTPCookieSecure : @(YES),
                                                                 NSHTTPCookieName : @"peanut",
                                                                 NSHTTPCookiePath : @"/",
                                                                 NSHTTPCookieValue : @"val"
                                                                 }];
    XCTAssertNotNil(cookie, @"Failed to instantiate a cookie");
    [jar setCookie: cookie];

    ANTCookieJar *copy = [jar mutableCopy];
    
    XCTAssertEqual([[jar cookiesForURL: [NSURL URLWithString: @"https://example.org"]] count], (NSUInteger) 1, @"Cookie not found");
    XCTAssertEqual([[copy cookiesForURL: [NSURL URLWithString: @"https://example.org"]] count], (NSUInteger) 1, @"Cookie not found");
}

- (void) testNonHTTP {
    ANTCookieJar *jar = [ANTCookieJar new];
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties: @{
        NSHTTPCookieDomain : @".example.org",
        NSHTTPCookieSecure : @(YES),
        NSHTTPCookieName : @"peanut",
        NSHTTPCookiePath : @"/",
        NSHTTPCookieValue : @"val"
    }];
    XCTAssertNotNil(cookie, @"Failed to instantiate a cookie");
    [jar setCookie: cookie];
    
    XCTAssertEqual([[jar cookiesForURL: [NSURL URLWithString: @"https://example.org"]] count], (NSUInteger) 1, @"Cookie not found");
    XCTAssertEqual([[jar cookiesForURL: [NSURL URLWithString: @"x-wat-protocol://example.org"]] count], (NSUInteger) 0, @"Cookie not found");
}

- (void) testCookiesForURL {
    ANTCookieJar *jar = [ANTCookieJar new];
    
    void (^AddCookie)(NSString *domain, BOOL secure, NSString *path, NSString *name, NSString *value) = ^(NSString *domain, BOOL secure, NSString *path, NSString *name, NSString *value) {
        NSMutableDictionary *props = [@{
            NSHTTPCookieDomain : domain,
            NSHTTPCookieName : name,
            NSHTTPCookiePath : path,
            NSHTTPCookieValue : value,
            NSHTTPCookieExpires : [NSDate distantFuture]
        } mutableCopy];

        /* If the property is set (to any value), the cookie will be considered 'secure'
         * by NSHTTPCookie */
        if (secure)
            [props setObject: @"true" forKey: NSHTTPCookieSecure];
        
        [jar setCookie: [NSHTTPCookie cookieWithProperties: props]];
    };
    NSArray *(^CookiesForURL)(NSString *str) = ^(NSString *str) {
        return [jar cookiesForURL: [NSURL URLWithString: str]];
    };
    
    /* Test domain handling */
    AddCookie(@".example.org", YES, @"/", @"domain1", @"v");
    AddCookie(@".example.com", YES, @"/", @"domain2", @"v");
    AddCookie(@"sub.example.org", YES, @"/", @"subdomain", @"v");

    NSArray *cookies = CookiesForURL(@"https://www.example.org");
    XCTAssertEqual([cookies count], (NSUInteger) 1, @"Incorrect number of cookies returned");
    XCTAssertEqualObjects([[cookies objectAtIndex: 0] path], @"/", @"Incorrect path returned");
    
    cookies = [CookiesForURL(@"https://sub.example.org/path") sortedArrayUsingSelector: @selector(name)];
    XCTAssertEqual([cookies count], (NSUInteger) 2, @"Incorrect number of cookies returned");
    XCTAssertEqualObjects([[cookies objectAtIndex: 0] name], @"domain1", @"Incorrect cookie returned");
    XCTAssertEqualObjects([[cookies objectAtIndex: 1] name], @"subdomain", @"Incorrect cookie returned");
    [jar deleteAllCookies];
    
    /* Test multi-path handling */
    AddCookie(@".example.org", YES, @"/", @"multipath", @"v");
    AddCookie(@".example.org", YES, @"/path", @"multipath", @"v");

    cookies = CookiesForURL(@"https://www.example.org");
    XCTAssertEqual([cookies count], (NSUInteger) 1, @"Incorrect number of cookies returned");
    XCTAssertEqualObjects([[cookies objectAtIndex: 0] path], @"/", @"Incorrect cookie returned");
    
    cookies = [CookiesForURL(@"https://www.example.org/path") sortedArrayUsingSelector: @selector(path)];
    XCTAssertEqual([cookies count], (NSUInteger) 2, @"Incorrect number of cookies returned");
    XCTAssertEqualObjects([[cookies objectAtIndex: 0] path], @"/path", @"Incorrect cookie returned");
    XCTAssertEqualObjects([[cookies objectAtIndex: 1] path], @"/", @"Incorrect cookie returned");
    [jar deleteAllCookies];
    
    /* Test 'secure' flag handling */
    AddCookie(@".example.org", YES, @"/", @"secure", @"v");
    AddCookie(@".example.org", NO, @"/", @"non-secure", @"v");

    cookies = CookiesForURL(@"https://www.example.org/");
    XCTAssertEqual([cookies count], (NSUInteger) 1, @"Incorrect number of cookies returned: %@", cookies);
    XCTAssertEqualObjects([[cookies objectAtIndex: 0] name], @"secure", @"Incorrect cookie returned");
    
    cookies = CookiesForURL(@"http://www.example.org/");
    XCTAssertEqual([cookies count], (NSUInteger) 1, @"Incorrect number of cookies returned");
    XCTAssertEqualObjects([[cookies objectAtIndex: 0] name], @"non-secure", @"Incorrect cookie returned");
    [jar deleteAllCookies];

    /* Test expiration handling */
    [jar setCookie: [NSHTTPCookie cookieWithProperties: @{
        NSHTTPCookieDomain : @".example.org",
        NSHTTPCookieName : @"name",
        NSHTTPCookiePath : @"/",
        NSHTTPCookieValue : @"value",
        NSHTTPCookieExpires : [NSDate distantPast]
    }]];
    [jar setCookie: [NSHTTPCookie cookieWithProperties: @{
        NSHTTPCookieDomain : @".example.org",
        NSHTTPCookieName : @"non-expired",
        NSHTTPCookiePath : @"/",
        NSHTTPCookieValue : @"value",
    }]];
    cookies = CookiesForURL(@"http://www.example.org/");
    XCTAssertEqual([cookies count], (NSUInteger) 1, @"Incorrect number of cookies returned");
    [jar deleteAllCookies];
}

@end
