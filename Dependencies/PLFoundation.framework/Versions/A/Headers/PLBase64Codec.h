/*
 * Copyright (c) 2012 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

@interface PLBase64Codec : NSObject

- (instancetype) init;

- (NSData *) dataWithString: (NSString *) base64String;
- (NSString *) stringWithData: (NSData *) data;

@end