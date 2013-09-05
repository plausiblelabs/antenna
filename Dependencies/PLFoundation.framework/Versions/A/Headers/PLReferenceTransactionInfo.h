/*
 * Copyright (c) 2012 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

/**
 * @internal
 *
 * Transaction states.
 */
typedef NS_ENUM(uint32_t, PLReferenceTransactionState) {
    /** An actively running transaction. */
    PLReferenceTransactionStateRunning = 0,

    /** The transaction is committing. */
    PLReferenceTransactionStateCommitting = 1,

    /** The transaction has been marked for retry, but has not yet been restarted. */
    PLReferenceTransactionStateRetry = 2,

    /** The transaction has been killed by a conflicting transaction, but has not yet been marked for retry. */
    PLReferenceTransactionStateKilled = 3,

    /** The transaction has been fully committed. */
    PLReferenceTransactionStateCommitted = 4
};


@interface PLReferenceTransactionInfo : NSObject

- (instancetype) initWithState: (PLReferenceTransactionState) state startPoint: (uint64_t) startPoint;
- (BOOL) isRunning;

@end