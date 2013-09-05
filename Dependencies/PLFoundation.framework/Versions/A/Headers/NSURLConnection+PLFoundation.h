/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

#import "PLCancelTicket.h"

@interface NSURLConnection (PLFoundation)

+ (void) pl_sendAsynchronousRequest: (NSURLRequest *)request
                              queue: (NSOperationQueue *)queue
                       cancelTicket: (PLCancelTicket *) ticket
                  completionHandler: (void (^)(NSURLResponse *response, NSData *data, NSError *error)) handler;

@end
