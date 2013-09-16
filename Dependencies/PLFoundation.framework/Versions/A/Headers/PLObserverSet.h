/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import "PLDispatchContext.h"

@interface PLObserverSet : NSObject

- (void) addObserver: (id) observer dispatchContext: (id<PLDispatchContext>) context;

- (void) removeObserver: (id) observer;

- (void) enumerateObservers: (void (^)(id observer)) block;
- (void) enumerateObserversRespondingToSelector: (SEL) selector block: (void (^)(id observer)) block;
@end