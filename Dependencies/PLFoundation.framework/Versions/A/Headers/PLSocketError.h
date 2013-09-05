/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>

/* Error Domain and Codes */
extern NSString *PLSocketErrorDomain;

extern NSString *PLSocketErrorOptionNameKey;
extern NSString *PLSocketErrorOptionLevelKey;

/**
 * NSError codes in the PLSocketErrorDomain. The underlying POSIX error will be available
 * via the NSUnderlyingErrorKey as an error in the NSPOSIXErrorDomain.
 */
typedef NS_ENUM(NSInteger, PLSocketError) {
    /** An unknown error occured. */
    PLSocketErrorUnknown = 0,

    /** An error occured opening the socket for listening. */
    PLSocketErrorListen = 1,

    /** An error occured binding an address to the socket. */
    PLSocketErrorBind = 2,

    /** An error occurred fetching the local socket address. */
    PLSocketErrorFetchLocalAddress = 3,

    /** An error occurred fetching the peer's socket address. */
    PLSocketErrorFetchPeerAddress = 4,

    /** An error occured creating a socket endpoint. */
    PLSocketErrorCreate = 5,

    /** An error occured setting a socket option. The integer name of the failed
     * option will be available from the userInfo dictionary via the PLSocketErrorOptionNameKey,
     * and the level will be available via the PLSocketErrorOptionLevelKey. */
    PLSocketErrorSetOption = 6,

    /** An error occured getting a socket option. The integer name of the failed
     * option will be available from the userInfo dictionary via the PLSocketErrorOptionNameKey,
     * and the level will be available via the PLSocketErrorOptionLevelKey. */
    PLSocketErrorGetOption = 7,

    /** An error occured accepting a new connection. */
    PLSocketErrorAccept = 8,
};

#ifdef PLFOUNDATION_PRIVATE
NSError *PLSocketErrorWithCode (PLSocketError code, int errnum, NSDictionary *userInfo);
#endif