/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

@interface PLObserverSet : NSObject

- (void) addObserver: (id ) observer queue: (dispatch_queue_t) queue;
- (void) removeObserver: (id) observer;

- (void) enumerateObservers: (void (^)(id observer)) block;
- (void) enumerateObserversRespondingToSelector: (SEL) selector block: (void (^)(id observer)) block;
@end