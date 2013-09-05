/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

#import "PLCancelTicket.h"

@interface PLCancelTicketSource : NSObject

- (instancetype) init;
- (instancetype) initWithTimeout: (NSTimeInterval) timeout;

- (instancetype) initWithLinkedTickets: (NSSet *) cancelTickets;

- (void) cancel;
- (void) cancelAfterTimeInterval: (NSTimeInterval) interval;

@property(nonatomic, readonly) PLCancelTicket *ticket;

@end
