/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */
#import <Foundation/Foundation.h>
#import <PLFoundation/PLPipe.h>

@interface PLSymmetricPipe : NSObject <PLPipeSink, PLPipeSource>
- (id) initWithSource: (id <PLPipeSource>) source sink: (id <PLPipeSink>) sink;
@end