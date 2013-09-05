/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

/**
 * Dispatch contexts represent an arbitrary synchronous or asynchronous (direct) execution
 * context on which blocks may be dispatched.
 *
 * Dispatch contexts are used to abstract the thread-safety requirements of a particular client of an API. They
 * may be direct (eg, immediate synchronous execution on the caller's thread), or indirect, in which
 * case execution will be performed asynchronously.
 *
 * The context type is not exposed to callers, and caller should not make assumptions regarding the
 * nature of the target context.
 *
 * @par Ordering Guarantees
 *
 * If the context implementation executes serially (eg, it is backed by a serial dispatch queue, or
 * by a standard runloop), then it must guarantee that all scheduled blocks will be executed in the
 * order they were enqueued.
 *
 * If the context implementation executes non-serially (eg, it executes directly and synchronously, or
 * using a concurrence dispatch queue), then no ordering guarantees are provided, and responsibility
 * for enforcing ordering invariants is delegated to whatever code is called by the block. In most cases,
 * this will be handled by clients using locks or some other synchronization mechanism;
 * it is not the concern of an API client scheduling a block, except insofar as it is necessary to
 * understand that blocks may be dispatched out-of-order.
 *
 * @par State and Dispatching
 *
 * Due to the complexity of maintaining ordering of asynchronous dispatches in a complex multi-threaded system,
 * API clients should avoid dispatching stateful messages; that is, messages that contain state that may be incorrect
 * if interpreted out of order. Since there is no guarantee that the target context synchronous, or that it
 * will order blocks as they are dispatched, there is no way to guarantee that stateful messages will accurately reflect
 * the current state of the process when they are executed, or that they will even reflect the actual ordering
 * of state changes within the process.
 *
 *  @par Thread Safety
 * Thread-safe. May be shared across threads.
 *
 * @par Implementation Notes
 * - Implementations must be thread-safe.
 * - -[PLDispatchContext performBlock:] must execute asynchronously. Synchronous execution on a distinct thread
 * introduces the risk of deadlocks.
 */
@protocol PLDispatchContext <NSObject>

/**
 * Schedule a block for execution. This may occur immediately and synchronously, or asynchronously,
 * depending on the implementation of the target context.
 */
- (void) performBlock: (void (^)(void)) block;

@end