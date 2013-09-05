/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */
#import <Foundation/Foundation.h>

#import <netinet/in.h>

#import <PLFoundation/PLSocketAddress.h>
#import <PLFoundation/PLInet6Address.h>

@interface PLInet6SocketAddress : NSObject <PLSocketAddress>

- (instancetype) initWithSocketAddress: (const struct sockaddr_in6 *) sa;

- (instancetype) initWithAddress: (PLInet6Address *) address port: (uint16_t) port;


/** IPv6 port. */
@property(nonatomic, readonly) in_port_t port;

@end