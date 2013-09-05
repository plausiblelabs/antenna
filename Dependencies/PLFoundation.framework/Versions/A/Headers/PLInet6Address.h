/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */
#import <Foundation/Foundation.h>

#import <PLFoundation/PLInetAddress.h>

#import <netinet/in.h>

@interface PLInet6Address : NSObject <PLInetAddress>

+ (instancetype) loopbackAddress;
+ (instancetype) anyAddress;

- (instancetype) initWithIPv6Address: (struct in6_addr) ipv6Address;
- (instancetype) initWithPresentationFormat: (NSString *) presentationFormat;

/** IPv6 Address, in network byte order. */
@property(nonatomic, readonly) struct in6_addr ipv6Address;

@end