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

#import "ANTPreferences.h"
#import "ANTNetworkClient.h"

#import <Security/Security.h>

/**
 * This notification is posted when a change is made to an ANTPreferences instance.
 * The notification object is the modified ANTPreferences object.
 */
NSString *ANTPreferencesDidChangeNotification = @"ANTPreferencesDidChangeNotification";

/* Internal notification used to track keychain updates. */
NSString *ANTPreferencesKeychainDidChangeNotification = @"ANTPreferencesDidChangeNotification";

static OSStatus ANTPreferencesKeychainCallback (SecKeychainEvent keychainEvent, SecKeychainCallbackInfo *info, void *context) {
    [[NSNotificationCenter defaultCenter] postNotificationName: ANTPreferencesKeychainDidChangeNotification object: nil];
    return noErr;
}

/**
 * Manages the ANT application preferences.
 */
@implementation ANTPreferences {
@private
    NSUserDefaults *_defaults;
    
    /** Cached keychain item. */
    EMInternetKeychainItem *_appleKeychainItem;
}

+ (void) initialize {
    if ([self class] != [ANTPreferences class])
        return;

    OSErr err;
    err = SecKeychainAddCallback(ANTPreferencesKeychainCallback, kSecAddEventMask|kSecDeleteEvent|kSecUpdateEvent|kSecPasswordChangedEvent|kSecKeychainListChangedMask, NULL);
    if (err != noErr)
        NSLog(@"Failed to add keychain callback: %d", err);
}

/**
 * Initialize a new instance.
 */
- (id) init {
    if ((self = [super init]) == nil)
        return nil;

    _defaults = [NSUserDefaults standardUserDefaults];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(defaultsDidChange:) name: NSUserDefaultsDidChangeNotification object: _defaults];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(keychainDidChange:) name: NSUserDefaultsDidChangeNotification object: nil];

    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

// ANTPreferencesKeychainDidChangeNotification notification
- (void) keychainDidChange: (NSNotification *) notification {
    /* This is a bit ham-fisted and should probably be narrowed down to actually fire on
     * events we care about */
    _appleKeychainItem = nil;
    [self defaultsDidChange: nil];
}

// NSUserDefaultsDidChangeNotification notification
- (void) defaultsDidChange: (NSNotification *) notification {
    [[NSNotificationCenter defaultCenter] postNotificationName: ANTPreferencesDidChangeNotification object: self];
}

/**
 * Set the user's default Apple ID.
 *
 * @param appleID New Apple ID.
 */
- (void) setAppleID: (NSString *) appleID {
    if ([appleID isEqual: self.appleID])
        return;
    
    if (appleID == nil) {
        [_defaults removeObjectForKey: @"ANTAppleID"];
        return;
    }

    [_defaults setObject: appleID forKey: @"ANTAppleID"];

    /* Invalidate the cached keychain item */
    _appleKeychainItem = nil;
}

/**
 * Return the user's default Apple ID, or nil if none.
 */
- (NSString *) appleID {
    return [_defaults stringForKey: @"ANTAppleID"];
}

/**
 * Return the keychain item for the user's Apple ID, or nil if none.
 */
- (EMInternetKeychainItem *) appleKeychainItem {
    /* Refuse to look up a nil/empty apple ID */
    if (self.appleID == nil ||
        [self.appleID length] == 0 ||
        [self.appleID rangeOfCharacterFromSet: [NSCharacterSet.whitespaceAndNewlineCharacterSet invertedSet]].location == NSNotFound)
    {
        return nil;
    }
    
    if (_appleKeychainItem != nil) {
        NSAssert([_appleKeychainItem.username isEqual: self.appleID], @"Incorrect keychain item cached");
        return _appleKeychainItem;
    }
    
    _appleKeychainItem = [EMInternetKeychainItem internetKeychainItemForServer: [[ANTNetworkClient bugReporterURL] host]
                                                                  withUsername: [self appleID]
                                                                          path: [[ANTNetworkClient bugReporterURL] path]
                                                                          port: [[[ANTNetworkClient bugReporterURL] port] integerValue]
                                                                      protocol: kSecProtocolTypeHTTPS];
    return _appleKeychainItem;
}

/**
 * Add and return new Apple ID keychain item with the given Apple ID and password.
 *
 * @param username The user's apple id.
 * @param password The user's password.
 *
 * If an error occurs, the return value will be nil.
 */
- (EMInternetKeychainItem *) addAppleKeychainItemWithUsername: (NSString *) username password: (NSString *) password {
    EMInternetKeychainItem *item;
    item = [EMInternetKeychainItem addInternetKeychainItemForServer: [[ANTNetworkClient bugReporterURL] host]
                                                       withUsername: username
                                                           password: password
                                                               path: [[ANTNetworkClient bugReporterURL] path]
                                                               port: [[[ANTNetworkClient bugReporterURL] port] integerValue]
                                                           protocol: kSecProtocolTypeHTTPS];

    /* Cache the newly added item */
    if ([username isEqual: self.appleID])
        _appleKeychainItem = item;
    
    [self defaultsDidChange: nil];
    return item;
}

@end
