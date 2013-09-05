/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <PLFoundation/PLPipe.h>

@interface PLCFStreamPipeSink : NSObject <PLPipeSink>

- (id) initWithWriteStream: (CFWriteStreamRef) writeStream;
- (id) initWithOutputStream: (NSOutputStream *) outputStream;

- (void) openStreamWithCompletionHandler: (void (^)(CFWriteStreamRef writeStream, NSError *error)) block;

@end