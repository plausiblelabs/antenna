/*
 * Copyright (c) 2010-2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

#import "PLDispatchContext.h"

/**
 * Cancellation ticket reasons.
 */
typedef NS_ENUM(NSInteger, PLCancelTicketReason) {
    /** Explicit cancellation was requested. @sa -[PLCancelTicketSource cancel]. */
    PLCancelTicketReasonRequested = 0,

    /**
     * A timeout was reached.
     *
     * @sa -[PLCancelTicketSource initWithTimeout:]
     * @sa -[PLCancelTicketSource cancelAfterTimeInterval:]
     */
    PLCancelTicketReasonTimeout = 2,
};

@interface PLCancelTicket : NSObject

- (void) addCancelHandler: (void (^)(PLCancelTicketReason reason)) handler;

- (void) addCancelHandler: (void (^)(PLCancelTicketReason reason)) handler
          dispatchContext: (id<PLDispatchContext>) dispatchContext;

/** YES if cancellation has been requested, NO otherwise. */
@property(nonatomic, readonly, getter = isCancelled) BOOL cancelled;

@end
