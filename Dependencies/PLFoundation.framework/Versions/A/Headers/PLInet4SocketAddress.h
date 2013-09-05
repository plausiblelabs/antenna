/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

#import <netinet/in.h>

#import <PLFoundation/PLSocketAddress.h>
#import <PLFoundation/PLInet4Address.h>

@interface PLInet4SocketAddress : NSObject <PLSocketAddress>

- (instancetype) initWithSocketAddress: (const struct sockaddr_in *) sa;
- (instancetype) initWithAddress: (PLInet4Address *) address port: (in_port_t) port;

/** IPv4 port. */
@property(nonatomic, readonly) in_port_t port;

@end
