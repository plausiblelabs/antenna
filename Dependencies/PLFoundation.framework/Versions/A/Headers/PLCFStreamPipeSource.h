/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <PLFoundation/PLPipe.h>


@interface PLCFStreamPipeSource : NSObject <PLPipeSource>

- (id) initWithReadStream: (CFReadStreamRef) readStream;
- (id) initWithInputStream: (NSInputStream *) inputStream;

- (void) openStreamWithCompletionHandler: (void (^)(CFReadStreamRef writeStream, NSError *error)) block;

@end