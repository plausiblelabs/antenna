/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <PLFoundation/PLDispatchContext.h>


@interface PLGCDDispatchContext : NSObject <PLDispatchContext>

+ (instancetype) mainQueueContext;

- (id) initWithQueue: (dispatch_queue_t) queue;

@end