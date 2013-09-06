/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

extern NSString *ANTErrorDomain;

/**
 * NSError codes in the ANTErrorDomain.
 */
typedef NS_ENUM(NSInteger, PLSocketError) {
    /** An unknown error occured. */
    ANTErrorUnknown = 0,
    
    /** The connection to the server was lost. */
    ANTErrorConnectionLost = 1,
    
    /** The server's response data was invalid. */
    ANTErrorResponseInvalid = 2,
    
    /** The request to the server timed out. */
    ANTErrorTimedOut = 3,
    
    /** The request was superceded by a conflicting request. */
    ANTErrorRequestConflict = 4,
    
    /** Authentication failed. */
    ANTErrorAuthenticationFailed = 5,
    
    /** Authentication required, but no credentials provided. */
    ANTErrorAuthenticationRequired = 6,
    
    /** The requesting principal does not have access to the requested resource. */
    ANTErrorPermissionDenied = 7,
    
    /** The request arguments were invalid (eg, incomplete or malformed). */
    ANTErrorInvalidRequest = 8,
    
    /** A requested resource was not found. */
    ANTErrorResourceNotFound = 9,
    
    /**
     * The network connection to the server is unavailable and can not be established automatically, either through
     * a lack of network connectivity, the user's explicit disabling of network connectivity, or due to technical
     * limitations of the underlying transport.
     */
    ANTErrorNetworkUnavailable = 10,
};