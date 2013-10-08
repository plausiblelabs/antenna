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

#import "ANTEffectiveTLDNames.c"

typedef enum {
    /** A standard TLD rule */
    TLDRuleTypeStandard = 0,
    
    /** A wildcard rule; everything *underneath* this rule is a TLD */
    TLDRuleTypeWildcard = 1,
    
    /** Exception rule; overrides a wildcard rule */
    TLDRuleTypeException = 2
} TLDRuleType;

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
 * Validate a cookie returned by the resource at @a theURL, rewriting the cookie's domain
 * if it references a TLD, or otherwise fails to conform to cookie domain rules.
 *
 * @param headerFields The header fields as returned from an NSHTTPURLResponse.
 * @param theURL The URL associated with the created cookies.
 *
 * @warning While there are RFCs that specify cookie requirements, none of the browsers actually
 * seem to follow them. This implementation is modeled on Chrome's CookieMonster
 * implementation ( http://www.chromium.org/developers/design-documents/network-stack/cookiemonster ),
 * and uses Mozilla's registry of TLDs (in a whitelist configuration) fetched from
 * http://publicsuffix.org/list/
 */
+ (NSHTTPCookie *) validateCookie: (NSHTTPCookie *) cookie forURL: (NSURL *) theURL {
    /* A simple block that replaces the cookie's domain with the URL's specified domain */
    NSHTTPCookie *(^ReplaceDomain)(void)  = ^(void) {
        NSMutableDictionary *props = [[cookie properties] mutableCopy];
        [props setObject: theURL.host forKey: NSHTTPCookieDomain];
        return [NSHTTPCookie cookieWithProperties: props];
    };

    /* If the cookie domain exactly matches the URL host, there's nothing else to validate */
    if ([cookie.domain compare: theURL.host options: NSCaseInsensitiveSearch] == NSOrderedSame) {
        return cookie;
    }
    
    /* If the URL uses an IP address, the cookie domain must also. */
    if ([[PLInet4Address alloc] initWithPresentationFormat: theURL.host] != nil || [[PLInet6Address alloc] initWithPresentationFormat: theURL.host]) {
        return ReplaceDomain();
    }
    
    /* If the cookie does not use a .domain host, or is not a prefix of the the URL's host, the cookie domain is invalid; the cookie
     * will be ignored. */
    NSString *lowercaseCookieDomain = [cookie.domain lowercaseString];
    if (![cookie.domain hasPrefix: @"."])
        return nil;
    
    if (![[@"." stringByAppendingString: [theURL.host lowercaseString]] hasSuffix: lowercaseCookieDomain])
        return nil;
    
    /* If we've gotten this far, we know that the cookie is a .domain.cookie, and that it matches the URL. We now
     * just need to search our TLD whitelist to ensure that:
     *
     * 1) The cookie domain is not a TLD.
     * 2) The cookie domain is within a known TLD. This ensures fail-safe behavior in the case that new TLDs are added.
     *
     * First, we need to strip leading '.' characters. */
    NSCharacterSet *periodCharSet = [NSCharacterSet characterSetWithCharactersInString: @"."];
    
    /* Now, we must walk the domain elements, searching for a valid TLD; if we match on the entirity of the domain,
     * we have to reject the attempt to set a .domain.tld cookie. */
    NSRange nextDot = NSMakeRange(0, 0);
    NSInteger wildCardExceptionDepth = -1;
    NSInteger domainDepth = 0;
    while (nextDot.location != NSNotFound) {
        /* If we've hit the end without matching on a TLD, this TLD isn't whitelisted and we have to enforce a host cookie domain */
        if (nextDot.location == NSNotFound)
            return ReplaceDomain();
        
        /* Our TLD table uses UTF-8 */
        NSString *lookupDomain = [lowercaseCookieDomain substringFromIndex: nextDot.location+1];
        const char *lookupDomainUTF8 = [lookupDomain UTF8String];
        size_t lookupDomainUTF8Len = strlen(lookupDomainUTF8);
        /* Ensure that our below cast to (unsigned int) is safe */
        if (lookupDomainUTF8Len > UINT_MAX) {
            /* Should never happen ... */
            NSLog(@"Received an exceptionally long domain name, skipping cookie: %@", lookupDomain);
            return nil;
        }
        
        /* Look up the rule */
        const struct TLDRule *rule = ANTTopLevelDomainTableLookup(lookupDomainUTF8, (unsigned int) lookupDomainUTF8Len);
        
        /*
         * Evaluate the rule. A matching rule doesn't necessarily terminate iteration, as we must
         * locate any wildcard rules for the domain
         *
         * Note that we have to validate the match string here, as perfect hashing refers to the items
         * within the set, and we're evaluating arbitrary domain names.
         */
        if (rule != NULL && strcmp(ANTTopLevelDomainTableStringPool+rule->name, lookupDomainUTF8) == 0) {

            /* Handle the rule types */
            if (rule->type == TLDRuleTypeStandard && domainDepth == 0) {
                /* The full domain is invalid */
                return ReplaceDomain();

            } else if (rule->type == TLDRuleTypeStandard) {
                /* The domain has a valid TLD! */
                return cookie;

            } else if (rule->type == TLDRuleTypeException) {
                /* The rule is excepted from a wildcard rule; we need to keep processing
                 * rules. */
                wildCardExceptionDepth = domainDepth;

            } else if (rule->type == TLDRuleTypeWildcard && wildCardExceptionDepth != domainDepth-1) {
                /* There's a wildcard rule, and no exception rule is in place */
                if (domainDepth == 1) {
                    /* The full domain is a TLD! */
                    return ReplaceDomain();
                } else {
                    /* The domain has a valid TLD! */
                    return cookie;
                }

            } else if (rule->type == TLDRuleTypeWildcard && wildCardExceptionDepth == domainDepth-1) {
                /* The domain falls within a wildcard TLD, but has an exception rule -- it's valid! */
                return cookie;

            } else {
                // Unreachable, unless we screwed up!
                __builtin_trap();
            }
        }
        
        /* Find the next '.' */
        nextDot = [lowercaseCookieDomain rangeOfCharacterFromSet: periodCharSet options: 0 range: NSMakeRange(nextDot.location+1, lowercaseCookieDomain.length - nextDot.location - 1)];
    
        /* Verify that our depth won't rollover. This really should *NEVER* happen ... */
        if (domainDepth == NSIntegerMax-1) {
            NSLog(@"The cookie domain components exceeded NSIntegerMax. That's sure some cookie!");
            return ReplaceDomain();
        }
        domainDepth++;
    };

    /* If a TLD rule was not found, the domain does not have a whitelisted TLD; we must reset the cookie
     * to be hostname-only */
    return ReplaceDomain();
}

/**
 * Returns an array of NSHTTPCookie objects corresponding to the provided response header fields for the provided URL.
 * The cookies will be validated to ensure that they correctly match @a theURL. Cookies specifying an invalid host
 * will be rewritten or discarded as necessary.
 *
 * @param headerFields The header fields as returned from an NSHTTPURLResponse.
 * @param theURL The URL associated with the created cookies.
 *
 * @sa ANTCookieJar::validateCookie:forURL:
 *
 * @note Unlike NSHTTPCookie's implementation, this method will validate the returned cookies host/domain values correctly
 * match @a theURL. Cookies specifying an invalid host will be rewritten or discarded as necessary.
 */
+ (NSArray *) cookiesWithResponseHeaderFields: (NSDictionary *) headerFields forURL: (NSURL *) theURL {
    NSArray *unfiltered = [NSHTTPCookie cookiesWithResponseHeaderFields: headerFields forURL: theURL];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity: unfiltered.count];
    for (NSHTTPCookie *cookie in unfiltered) {
        NSHTTPCookie *validated = [self validateCookie: cookie forURL: theURL];
        if (validated != nil)
            [results addObject: validated];
    }

    return results;
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
