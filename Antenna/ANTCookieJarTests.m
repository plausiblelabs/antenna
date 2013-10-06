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

    XCTAssertNotNil([jar cookiesForURL: [NSURL URLWithString: @"https://example.org/path"]], @"Cookie not found");
    
    /* Test deletion */
    [jar deleteCookie: cookie];
    XCTAssertEqual([[jar cookiesForURL: [NSURL URLWithString: @"https://example.org/path"]] count], (NSUInteger) 0, @"Cookie not deleted");
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
    cookies = CookiesForURL(@"http://www.example.org/");
    XCTAssertEqual([cookies count], (NSUInteger) 0, @"Incorrect number of cookies returned");
    [jar deleteAllCookies];
}

@end
