/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <sys/socket.h>

@interface PLSocketOption : NSObject

+ (instancetype) reuseAddressOption;
- (instancetype) initWithLevel: (int) level name: (int) name intValue: (int) value;

- (instancetype) initWithLevel: (int) level name: (int) name value: (NSData *) value;

- (int) intValue;

/** Protocol level. This will generally be SOL_SOCKET. */
@property(nonatomic, readonly) int level;

/** Option name (eg, SO_REUSEADDR). */
@property(nonatomic, readonly) int name;

/** Option value. */
@property(nonatomic, readonly) NSData *value;

@end