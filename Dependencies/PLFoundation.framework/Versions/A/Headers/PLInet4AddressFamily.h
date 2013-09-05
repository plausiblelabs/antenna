/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <PLFoundation/PLAddressFamily.h>


@interface PLInet4AddressFamily : NSObject <PLAddressFamily>

+ (instancetype) addressFamily;

@end