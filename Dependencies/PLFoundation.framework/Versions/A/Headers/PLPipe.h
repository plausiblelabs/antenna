/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

/* Error Domain and Codes */
extern NSString *PLPipeErrorDomain;

/**
 * NSError codes in the PLPipeErrorDomain.
 */
typedef NS_ENUM(NSInteger, PLPipeError) {
    /** An unknown error occured. */
    PLPipeErrorUnknown = 0,

    /** A write error occured. */
    PLPipeErrorWrite = 1,

    /** A read error occured. */
    PLPipeErrorRead = 2,

    /** An attempt was made to perform I/O on a closed stream. */
    PLPipeErrorClosed = 3,

    /** The I/O request timed out. */
    PLPipeErrorTimedOut = 4,

    /** The other side of the stream pipe was closed. */
    PLPipeErrorBrokenPipe = 5,

    /** A user-specified byte limit was exceeded. */
    PLPipeErrorLimitExceeded = 6,

    /** The userq's disk quota has been exhausted. */
    PLPipeErrorQuotaExhausted = 7,

    /** No free space remains in the requested destination. */
    PLPipeErrorInsufficientSpace = 8,

    /** The requested operation is not supported. */
    PLPipeErrorOperationNotSupported = 9,

    /**
     * Network reachability to the destination appears to be unavailable and can not be established automatically,
     * either due to a lack of network connectivity, the user's explicit disabling of networking, or due to
     * technical constraints of the underlying transport, such as EDGE's inability to support concurrent voice
     * and data.
     */
    PLPipeErrorNetworkUnreachable = 10
};

#ifdef PLFOUNDATION_PRIVATE
NSError *PLPipeErrorWithCode (PLPipeError code, NSError *cause);
#endif


/**
 * Represents a read-only stream of bytes.
 *
 * @par Thread-Safety
 * Thread-safe. May be shared across threads.
 *
 * @par Implementation Notes
 *
 * - Implementations must be usable from any thread without external locking.
 * - Implementations must immediately restart any signal-interrupted I/O requests.
 */
@protocol PLPipeSource

/**
 * Read up to @a length bytes from the receiver.
 *
 * @param length The maximum number of bytes to read. Pass 0 to continue reading until EOF is reached.
 * @param queue The queue on which @a handler will be scheduled.
 * @param completionBlock The handler to be called when data is available. The handler may be called multiple times until
 * up to @a length bytes are read. If all all available data (up to @a length) has been read, 'done' will be YES. If an error occurs,
 * the error parameter will be non-nil and an error in the PLPipeErrorDomain will be provided.
 */
- (void) readLength: (size_t) length
              queue: (dispatch_queue_t) queue
    completionBlock: (void (^)(BOOL done, dispatch_data_t data, NSError *error)) completionBlock;

/**
 * Close the stream, releasing all associated system resources. A best effort will be made to cancel pending
 * asynchronous requests; affected requests will return a PLPipeErrorClosed error, along with any partially
 * written data.
 */
- (void) close;

@end

/**
 * Represents a write-only stream of bytes.
 *
 * @par Thread-Safety
 * Thread-safe. May be shared across threads.
 *
 * @par Implementation Notes
 *
 * - Implementations must be usable from any thread without external locking.
 * - Implementations must immediately restart any signal-interrupted I/O requests.
 *
 * @todo Figure out if we need a specifial -flush method, or if we can get away with being smart about handling
 * completion of write requests. This will become apparent when we've implemented a few buffering filters, but
 * I believe it's possible.
 */
@protocol PLPipeSink

/**
 * Write all of @a data to the receiver.
 *
 * @param data The buffer to be written to the receiver
 * @param queue The queue on which @a handler will be scheduled.
 * @param completionBlock The handler to be called when data has been written. The handler may be called multiple times until
 * the full set of available data has been written, at which point the handler will be called with a 'done' parameter of YES. If an error occurs,
 * the error parameter will be non-nil and an error in the PLPipeErrorDomain will be provided.
 *
 * @par Flushing buffered data
 *
 * If supported by the receiver, buffered data may be flushed by writing dispatch_empty_data to the pipe sink.
 */
- (void) writeData: (dispatch_data_t) data
             queue: (dispatch_queue_t) queue
   completionBlock: (void (^)(BOOL done, dispatch_data_t remaining, NSError *error)) completionBlock;

/**
 * Close the stream, releasing all associated system resources. A best effort will be made to cancel pending
 * asynchronous requests; affected requests will return a PLPipeErrorClosed error, along with any partially
 * written data.
 */
- (void) close;

@end
