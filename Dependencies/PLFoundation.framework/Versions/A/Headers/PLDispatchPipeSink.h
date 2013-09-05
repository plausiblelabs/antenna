/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <PLFoundation/PLPipe.h>


@interface PLDispatchPipeSink : NSObject <PLPipeSink>

- (instancetype) initWithFileDescriptor: (int) fd closeWhenDone: (BOOL) closeWhenDone;
- (instancetype) initWithChannel: (dispatch_io_t) channel;

@end