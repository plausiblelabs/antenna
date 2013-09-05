/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

#import <PLFoundation/PLAddressFamily.h>
#import <PLFoundation/PLSocketAddress.h>
#import <PLFoundation/PLSocketOption.h>
#import <PLFoundation/PLSocketError.h>

#import "PLCancelTicket.h"

#import <sys/socket.h>

/**
 * A socket that may be closed.
 */
@protocol PLCloseableSocket <NSObject>

/**
 * Close the socket. Currently scheduled asynchronous operations may execute after this method
 * has been called
 *
 * @todo See if we can provide any guarantee about close ordering relative to async operations.
 */
- (void) close;

@end

/**
 * A named (locally bound) socket. The socket may or may not
 * be connected.
 */
@protocol PLNamedSocket <NSObject>
- (id<PLSocketAddress>) localAddress: (NSError **) outError;
@end

/**
 * A bound and connected socket.
 */
@protocol PLConnectedSocket <PLNamedSocket, NSObject>
- (id<PLSocketAddress>) peerAddress: (NSError **) outError;
@end

/**
 * A socket that supports connecting to a remote peer.
 */
@protocol PLConnectableSocket <NSObject>

/**
 * Asynchronously connect to the the given @a socketAddress.
 *
 * On successfully establishing a connection, @a handler will be called with a valid connected socket and a nil error value.
 * On error the connected argument will be nil, and a PLSocketErrorAccept error in the PLSocketErrorDomain will be provided.
 *
 * @param socketAddress The peer address to connect to.
 * @param type The socket type, as defined by socket(2) (eg, SOCK_STREAM, SOCK_DGRAM). Not all types are supported
 * by all protocols, in which case an EPROTOTYPE error will be returned.
 * @param ticket Asynchronous cancellation ticket. May be used to cancel the request prior to connection establishment.
 * @param queue The queue on which the connection handler will be scheduled.
 * @param handler The handler to be called upon establishing a new connection, or receiving an error.
 */
- (void) connectSocketWithAddress: (id<PLSocketAddress>) socketAddress
                             type: (int) type
                           ticket: (PLCancelTicket *) ticket
                            queue: (dispatch_queue_t) queue
                          handler: (void (^)(id<PLConnectedSocket> connected, NSError *error)) handler;
@end

/**
 * A bound socket that is accepting connections.
 */
@protocol PLAcceptSocket <PLCloseableSocket>
@end

/**
 * A bound, listening socket that may be used to accept new connections.
 */
@protocol PLListenSocket <PLNamedSocket>

/**
 * Begin accepting connections on the receiver using @a handler.
 *
 * On successfully accepting a connection, @a handler will be called with for each new valid client socket, using a nil error value. If
 * an error occurs accepting a connection, the client argument will be nil, and a PLSocketErrorAccept error in the PLSocketErrorDomain
 * will be provided.
 *
 * The returned PLAcceptSocket may be closed, after which no additional connections will be accepted.
 *
 * @note While multiple accept sockets may be created from a single given listen socket, be aware that there is no performance
 * advantage to do doing so.
 *
 * @param queue The queue on which the accept handler will be scheduled.
 * @param handler The handler to be called upon accepting a new connection, or receiving an error.
 */
- (id<PLAcceptSocket>) acceptSocketWithQueue: (dispatch_queue_t) queue handler: (void (^)(id<PLConnectedSocket> client, NSError *error)) handler;

/**
 * Return a block that may be used to accept connections on the receiver, returning the newly configured accept socket.
 * This is equivalent to the PLListenSocket::acceptSocketWithQueue:handler: method.
 */
@property(nonatomic, readonly) id<PLAcceptSocket> (^accept)(dispatch_queue_t queue, void (^handler)(id<PLConnectedSocket> client, NSError *error));

@end


/**
 * A locally bound, unconnected socket.
 */
@protocol PLBoundSocket <PLConnectableSocket, NSObject>

/**
 * Configure the socket for listening, and return the newly configured listen socket.
 *
 * @param backlog The maximum queue of pending connections that will be maintained. See also the listen(2) man page.
 * and type. See bind(2) and socket(2) for more details.
 * @param [out] outError On error -- if non-NULL, an appropriate error in the PLSocketErrorDomain will be provided.
 *
 * @return Returns a bound listen socket on success, or nil on error.
 */
- (id<PLListenSocket>) listenSocketWithBacklog: (int) backlog error: (NSError **) outError;

/**
 * Return a block that may be used to configure the socket for listening, returning the newly configured listen socket.
 * This is equivalent to the PLBoundSocket::listenSocketWithBacklog: method.
 */
@property(nonatomic, readonly) id<PLListenSocket> (^listen)(int backlog, NSError **outError);

@end

/**
 * An unbound and unconnected socket, configured for use with a given address family.
 */
@protocol PLSocket <PLConnectableSocket, NSObject>


/**
 * Return a bound socket for the given @a socketAddress.
 *
 * @param socketAddress The address to which the socket should be bound.
 * @param type The socket type, as defined by socket(2) (eg, SOCK_STREAM, SOCK_DGRAM). Not all types are supported
 * by all protocol, in which case nil will be returned.
 *
 * @return Returns a bound listen socket on success, or nil on error.
 */
- (id<PLBoundSocket>) bindSocketWithAddress: (id <PLSocketAddress>) socketAddress
                                       type: (int) type;

/**
 * Return a block that may be used to bind and return a new socket instance. This is equivalent to the
 * PLSocket::bindSocketWithAddress:type: method.
 */
@property(nonatomic, readonly) id<PLBoundSocket> (^bind)(id<PLSocketAddress> address, int type);

@end

@interface PLSocket : NSObject <PLSocket>

+ (instancetype) socket;

- (id) init;
- (id) initWithSocketOptions: (NSArray *) options;

- (instancetype) socketByAppendingSocketOption: (PLSocketOption *) option;

/** Return a block that may be used to create a new socket with the given socket option appended. This is equivalent to the
 * PLSocket::socketByAppendingSocketOption: method. */
@property(nonatomic, readonly) PLSocket *(^setsockopt)(PLSocketOption *option);

@end