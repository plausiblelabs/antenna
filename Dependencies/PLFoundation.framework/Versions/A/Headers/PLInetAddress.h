/*
 * Copyright (c) 2012 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <sys/socket.h>

/**
 * This protocol represents an Internet Protocol (IP) address.
 */
@protocol PLInetAddress <NSObject>

/** The address data, in network byte order. */
@property(nonatomic, readonly) NSData *addressData;

/** The address family (generally AF_INET or AF_INET6) */
@property(nonatomic, readonly) sa_family_t sa_family;

/** The address's presentation format (human-readable string representation). */
@property(nonatomic, readonly) NSString *presentationFormat;

@end