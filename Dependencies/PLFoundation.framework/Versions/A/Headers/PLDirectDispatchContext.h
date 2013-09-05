/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <PLFoundation/PLDispatchContext.h>

@interface PLDirectDispatchContext : NSObject <PLDispatchContext>

+ (instancetype) context;

@end