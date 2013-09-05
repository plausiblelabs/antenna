/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

@interface NSError (PLFoundation)

+ (id) pl_errorWithDomain: (NSString *) domain
                     code: (NSInteger) code
     localizedDescription: (NSString *) localizedDescription
   localizedFailureReason: (NSString *) localizedFailureReason
          underlyingError: (NSError *) underlyingError
                 userInfo: (NSDictionary *) userInfo;

@end