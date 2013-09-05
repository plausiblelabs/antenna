/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <PLFoundation/PLDispatchContext.h>

@interface PLRunLoopThread : NSObject <PLDispatchContext>

+ (instancetype) defaultThread;

- (void) stop;

@end