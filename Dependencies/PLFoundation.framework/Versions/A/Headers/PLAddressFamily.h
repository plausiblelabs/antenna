/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

#import <sys/socket.h>

@protocol PLSocketAddress;

/**
 * This class represents a generic network address family. Provides an Objective-C interface to the BSD sockaddr
 * structures.
 */
@protocol PLAddressFamily <NSObject>


/**
 * Create and return an unnamed socket appropriate for the receiver's address family.
 *
 * @param type The socket type, as defined by socket(2) (eg, SOCK_STREAM, SOCK_DGRAM). Not all types are supported
 * by all protocols, in which case an EPROTOTYPE error will be returned.
 * @param [out] outError On error -- if non-NULL, an appropriate error in the PLSocketErrorDomain will be provided.
 *
 * @return Returns a new socket file descriptor on success, or -1 on error. It is the caller's responsibility to
 * close(2) the returned socket.
 *
 * @note See the socket(2) man page for possible error values.
 */
- (int) socketWithType: (int) type error: (NSError **) outError;

/**
 * Return a PLSocketAddress instance for the given @a sockaddr. If sockaddr is not
 * within the receiver's expected address family, nil will be returned.
 *
 * @param sockaddr The backing sockaddr structure.
 */
- (id<PLSocketAddress>) socketAddressWithStructure: (const struct sockaddr *) sockaddr;

/** The receiver's socket address family value. */
@property(nonatomic, readonly) sa_family_t sa_family;

@end

#import <PLFoundation/PLSocketAddress.h>
