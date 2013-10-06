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

#import "ANTCookieJar.h"
#import <PLFoundation/PLFoundation.h>

/**
 * Provides a thread-safe, non-singleton replacement for NSHTTPCookieStorage.
 */
@implementation ANTCookieJar {
    /** Lock that must be held when accessing _storage. */
    OSSpinLock _lock;

    /** Cookie storage. Maps (domain -> path -> cookie name -> NSHTTPCookie). */
    NSMutableDictionary *_storage;
}

/**
 * Initialize a new instance.
 */
- (instancetype) init {
    PLSuperInit();
    
    _lock = OS_SPINLOCK_INIT;
    _storage = [NSMutableDictionary dictionary];

    return self;
}

// from NSCopying
- (instancetype) mutableCopyWithZone: (NSZone *) zone {
    ANTCookieJar *copy = [ANTCookieJar new];

    OSSpinLockLock(&_lock); {
        for (NSString *domain in _storage) {
            for (NSString *path in _storage[domain]) {
                for (NSString *name in _storage[domain][path]) {
                    [copy setCookie: _storage[domain][path][name]];
                }
            }
        }
    } OSSpinLockUnlock(&_lock);
    
    return copy;
}

/**
 * Add @a aCookie to the receiver.
 *
 * @param aCookie The cookie to be added.
 */
- (void) setCookie: (NSHTTPCookie *) aCookie {
    /* Fetches 'key' in 'source', creating the value via 'create' if not availabile. */
    id (^getOrCreate)(NSMutableDictionary *source, id key, id (^create)(void)) = ^(NSMutableDictionary *source, id key, id (^create)(void)) {
        id obj = source[key];
        if (obj != nil)
            return obj;
        
        obj = create();
        source[key] = obj;
        return obj;
    };

    /* Add the cookie */
    OSSpinLockLock(&_lock); {
        NSMutableDictionary *domain = getOrCreate(_storage, aCookie.domain, ^{ return [NSMutableDictionary new]; });
        NSMutableDictionary *cookies = getOrCreate(domain, aCookie.path, ^{ return [NSMutableDictionary new]; });
        cookies[aCookie.name] = aCookie;
    } OSSpinLockUnlock(&_lock);
}

/**
 * Delete @a aCookie.
 *
 * @param aCookie The cookie to be deleted.
 */
- (void) deleteCookie: (NSHTTPCookie *) aCookie {
    OSSpinLockLock(&_lock); {
        [_storage[aCookie.domain][aCookie.path] removeObjectForKey: aCookie.name];

        /* Clean up empty path entries */
        if ([_storage[aCookie.domain][aCookie.path] count] == 0)
            [_storage[aCookie.domain] removeObjectForKey: aCookie.path];
        
        /* Clean up empty domains */
        if ([_storage[aCookie.domain] count] == 0)
            [_storage removeObjectForKey: aCookie.domain];
    }; OSSpinLockUnlock(&_lock);
}



/**
 * Return all cookies associated with @a theURL.
 *
 * @param theURL The target URL.
 */
- (NSArray *) cookiesForURL: (NSURL *) theURL {
    /* Check if secure */
    BOOL secure = NO;
    if ([[theURL scheme] compare: @"https" options: NSCaseInsensitiveSearch] == NSOrderedSame)
        secure = YES;

    /* Only HTTP/HTTPS are supported */
    if (![theURL.scheme isEqual: @"http"] && ![theURL.scheme isEqual: @"https"])
        return @[];

    /* As per RFC 2965, we can ignore the port list attribute; cookies
     * do not provide isolation by port within a given domain. */
    NSMutableArray *results = [NSMutableArray array];
    OSSpinLockLock(&_lock); {
        for (NSString *domain in _storage) {
            /* Verify that the domain matches */
            NSString *urlPrefixHost = theURL.host;
            if (![urlPrefixHost hasPrefix: @"."])
                urlPrefixHost = [@"." stringByAppendingString: urlPrefixHost];
            
            if (![domain isEqual: theURL.host] && !([domain hasPrefix: @"."] && [urlPrefixHost hasSuffix: domain]))
                continue;
            
            /* Find all matching paths */
            for (NSString *path in _storage[domain]) {
                /* Check the path -- we rewrite empty paths to '/' for comparison. */
                NSString *urlPath = theURL.path;
                if ([urlPath length] == 0)
                    urlPath = @"/";

                if (![urlPath hasPrefix: path])
                    continue;
                
                /* Iterate all cookies within the path */
                NSDate *now = [NSDate date];
                NSMutableArray *expired = [NSMutableArray array];
                for (NSString *name in _storage[domain][path]) {
                    NSHTTPCookie *cookie = _storage[domain][path][name];
                    
                    /* Check for expiration */
                    if (cookie.expiresDate != nil && [[cookie.expiresDate laterDate: now] isEqual: now]) {
                        [expired addObject: name];
                        continue;
                    }
                    
                    /* Check for 'secure' flag; we don't provide non-secure cookies for secure connections. */
                    if (cookie.isSecure != secure)
                        continue;
                    
                    /* Add to results */
                    [results addObject: cookie];
                }
                
                /* Clean up expired cookies */
                for (NSString *name in expired) {
                    [_storage[domain][path] removeObjectForKey: name];
                }
                
                if ([_storage[domain][path] count] == 0)
                    [_storage[domain] removeObjectForKey: path];
            }
            
            /* Clean up empty domains */
            if ([_storage[domain] count] == 0)
                [_storage removeObjectForKey: domain];
        }
    } OSSpinLockUnlock(&_lock);
    
    return results;
}

/**
 * Delete all cookies stored in the receiver.
 */
- (void) deleteAllCookies {
    OSSpinLockLock(&_lock); {
        [_storage removeAllObjects];
    } OSSpinLockUnlock(&_lock);
}

@end
