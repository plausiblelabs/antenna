/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <PLFoundation/PLAddressFamily.h>
#import <sys/socket.h>

/**
 * This class represents a generic network socket address. Provides an Objective-C interface to the BSD sockaddr
 * structure.
 */
@protocol PLSocketAddress <NSObject>

/**
 * The receiver's address family.
 */
@property(nonatomic, readonly) id<PLAddressFamily> addressFamily;

/**
 * Generic sockaddr representation of the receiver in network byte order.
 *
 * @note The returned memory is automatically released just as a returned object would be; you must copy
 * the data if it needs to be stored outside of the current autorelease context.
 */
@property(nonatomic, readonly) const struct sockaddr *sockaddr;

/** Length of the sockaddr structure for this receiver. Note that this may differ for individual socket addresses; when using
 * extensions to APIs such as sockaddr_un, the actual structure may be dynamically sized to fit the target path. */
@property(nonatomic, readonly) socklen_t sockaddr_len;

@end