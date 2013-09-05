/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <PLFoundation/PLInetAddress.h>

#import <netinet/in.h>

@interface PLInet4Address : NSObject <PLInetAddress>

+ (instancetype) loopbackAddress;
+ (instancetype) anyAddress;

- (instancetype) initWithIPv4Address: (in_addr_t) ipv4Address;
- (instancetype) initWithPresentationFormat: (NSString *) presentationFormat;

/** IPv4 Address, in network byte order. */
@property(nonatomic, readonly) in_addr_t ipv4Address;

@end