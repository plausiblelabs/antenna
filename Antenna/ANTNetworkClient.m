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

#import "ANTNetworkClient.h"
#import "ANTLoginWindowController.h"

#import "MAErrorReportingDictionary.h"
#import "NSObject+MAErrorReporting.h"

/**
 * @defgroup contents_network_folders Radar Folder Constants
 * @{
 */

/** Attention folder. Items that require user response. */
NSString *ANTNetworkClientFolderTypeAttention = @"Attention";

/** Open bug reports. */
NSString *ANTNetworkClientFolderTypeOpen = @"Open";

/** Closed, non-archived bug reports. */
NSString *ANTNetworkClientFolderTypeClosed = @"Closed";

/** Closed, archived bug reports. */
NSString *ANTNetworkClientFolderTypeArchive = @"Archive";

/** Saved drafts. */
NSString *ANTNetworkClientFolderTypeDrafts = @"Drafts";

/**
 * @}
 */

@interface ANTNetworkClient ()
@end

@implementation ANTNetworkClient {
@private
    /** Base URL for all requests. */
    NSURL *_bugReporterURL;

    /** The backing authentication delegate */
    __weak id<ANTNetworkClientAuthDelegate> _authDelegate;

    /** Lock that must be held when accessing mutable internal state. */
    OSSpinLock _lock;

    /** Current authentication state. */
    ANTNetworkClientAuthState _authState;

    /** The authentication result, if available. Nil if authentication has not completed or has been invalidated. */
    ANTNetworkClientAuthResult *_authResult;

    /** Date formatter to use for report dates (DD-MON-YYYY HH:MM) */
    NSDateFormatter *_dateFormatter;

    /** Internal queue used to handle NSURLConnection callbacks */
    NSOperationQueue *_opQueue;
    
    /** Registered observers. */
    PLObserverSet *_observers;
}

/**
 * Return the default bug reporter URL.
 */
+ (NSURL *) bugReporterURL {
    return [NSURL URLWithString: @"https://bugreport.apple.com"];
}

/**
 * Initialize a new instance.
 *
 * @param authDelegate The authentication delegate for this client instance. The reference will be held weakly.
 */
- (instancetype) initWithAuthDelegate: (id<ANTNetworkClientAuthDelegate>) authDelegate {
    if ((self = [super init]) == nil)
        return nil;
    
    _lock = OS_SPINLOCK_INIT;
    _authDelegate = authDelegate;
    _authState = ANTNetworkClientAuthStateLoggedOut;

    /* Use the default remote URL */
    _bugReporterURL = [ANTNetworkClient bugReporterURL];

    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"dd-MMM-yyyy HH:mm"];
    [_dateFormatter setLocale: [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
    
    _opQueue = [NSOperationQueue new];
    _observers = [PLObserverSet new];
    
    return self;
}

/**
 * Register an @a observer to which messages will be dispatched via @a context.
 *
 * @param observer The observer to add to the set. It will be weakly referenced.
 * @param context The context on which messages to @a observer will be dispatched.
 */
- (void) addObserver: (id<ANTNetworkClientObserver>) observer dispatchContext: (id<PLDispatchContext>) context {
    [_observers addObserver: observer dispatchContext: context];
}

/**
 * Remove an observer.
 *
 * @param observer Observer registration to be removed.
 */
- (void) removeObserver: (id<ANTNetworkClientObserver>) observer {
    [_observers removeObserver: observer];
}

/**
 * Request all radar issue summaries for the the given section names.
 *
 * @param sectionNames The section names to be fethed. The result order is undefined. @sa @ref contents_network_folders.
 * @param ticket A request cancellation ticket.
 * @param completionHandler The block to call upon completion. If an error occurs, error will be non-nil. The summaries
 * will be provided as an ordered array of ANTRadarSummaryResponse values.
 */
- (void) requestSummariesForSections: (NSArray *) sectionNames
                        cancelTicket: (PLCancelTicket *) ticket
                     dispatchContext: (id<PLDispatchContext>) context
                   completionHandler: (void (^)(NSArray *summaries, NSError *error)) handler
{
    NSMutableSet *pending = [NSMutableSet setWithArray: sectionNames];
    NSMutableArray *results = [NSMutableArray array];
    __block OSSpinLock pendingLock = OS_SPINLOCK_INIT;

    PLCancelTicketSource *internalTicketSource = [[PLCancelTicketSource alloc] initWithLinkedTickets: [NSSet setWithObjects: ticket, nil]];
    for (NSString *name in sectionNames) {
        [self requestSummariesForSection: name cancelTicket: internalTicketSource.ticket dispatchContext: [PLDirectDispatchContext context] completionHandler: ^(NSArray *summaries, NSError *error) {
            NSUInteger remaining;
            
            /* Perform all mutation with the lock held */
            OSSpinLockLock(&pendingLock); {
                /* If an error occured elsewhere in one of the other fetches, we'll be cancelled. We check
                 * this with our lock held to ensure strict ordering of cancellation handling. */
                if (internalTicketSource.ticket.isCancelled) {
                    OSSpinLockUnlock(&_lock);
                    return;
                }

                /*
                 * Handle errors:
                 * - Cancel all other pending requests
                 * - Report the error
                 */
                if (error != nil) {

                    [internalTicketSource cancel];
                    
                    /* We can't call out to cancellation handlers with our lock held */
                    OSSpinLockUnlock(&pendingLock);
                    
                    /* Note cancellation and return */
                    [context performWithCancelTicket: ticket block:^{
                        handler(nil, error);
                    }];
                    return;
                }
                
                [pending removeObject: name];
                [results addObjectsFromArray: summaries];
                remaining = [pending count];
            } OSSpinLockUnlock(&pendingLock);
            
            /* Check for (and report!) completion */
            if (remaining == 0) {
                [context performWithCancelTicket: ticket block:^{
                    handler(results, nil);
                }];
            }
        }];
    }
}

/**
 * Request all radar issue summaries for @a sectionName.
 *
 * @param sectionName The section to be fethed. The result order is undefined. @sa @ref contents_network_folders.
 * @param ticket A request cancellation ticket.
 * @param dispatchContext The dispatch context on which @a handler will be called.
 * @param completionHandler The block to call upon completion. If an error occurs, error will be non-nil. The summaries
 * will be provided as an ordered array of ANTRadarSummaryResponse values.
 *
 * @todo Implement paging support.
 * @todo Allow for specifying the sort order.
 */
- (void) requestSummariesForSection: (NSString *) sectionName
                       cancelTicket: (PLCancelTicket *) ticket
                    dispatchContext: (id<PLDispatchContext>) context
                  completionHandler: (void (^)(NSArray *summaries, NSError *error)) handler
{
    NSDictionary *req = @{@"reportID" : sectionName, @"orderBy" : @"DateOriginated,Descending", @"rowStartString":@"1" };
    [self postJSON: req toPath: @"/developer/problem/getSectionProblems" cancelTicket: ticket dispatchContext: context completionHandler:^(id jsonData, NSError *error) {
        /* Verify the response type */
        if (![jsonData isKindOfClass: [NSDictionary class]]) {
            handler(nil, [NSError errorWithDomain: NSCocoaErrorDomain code: NSURLErrorCannotParseResponse userInfo: nil]);
            return;
        }
    
        /* Parse out the data */
        MAErrorReportingDictionary *jsonDict = [[MAErrorReportingDictionary alloc] initWithDictionary: jsonData];
        id (^Check)(id) = ^(id value) {
            if (value == nil) {
                NSError *error = [NSError pl_errorWithDomain: ANTErrorDomain
                                                        code: ANTErrorInvalidResponse
                                        localizedDescription: NSLocalizedString(@"Unable to parse the server result.", nil)
                                      localizedFailureReason: NSLocalizedString(@"Response data is missing a required value.", nil)
                                             underlyingError: [jsonDict error] userInfo: nil];
                handler(nil, error);
                return (id) nil;
            }
            
            return value;
        };
        
#define GetValue(_varname, _type, _source) \
    _type *_varname = Check([_type ma_castRequiredObject: _source]); \
    if (_varname == nil) { \
        NSLog(@"Missing required var " # _source " in %@", jsonDict); \
        return; \
    }

        /* It's called a list, but it's actually a dictionary. Go figure */
        GetValue(list, NSDictionary, jsonDict[@"List"]);
        GetValue(issues, NSArray, list[@"RDRGetMyOrignatedProblems"]);
        
        /* Regex to match radar attribution lines, eg, '<GMT09-Aug-2013 21:14:47GMT> Landon Fuller:' */
        NSRegularExpression *attributionLineRegex;
        attributionLineRegex = [NSRegularExpression regularExpressionWithPattern: @"<[A-Z0-9+]+-[A-Za-z]+-[0-9]+ [0-9]+:[0-9]+:[0-9]+[A-Z0-9+]+> .*:[ \t\n]*"
                                                                         options: NSRegularExpressionAnchorsMatchLines
                                                                           error: &error];
        NSAssert(attributionLineRegex != nil, @"Failed to compile regex");

        NSMutableArray *results = [NSMutableArray arrayWithCapacity: [issues count]];
        for (id issueVal in issues) {
            GetValue(issue, NSDictionary, issueVal);
            GetValue(radarId,           NSNumber,   issue[@"problemID"]);
            GetValue(stateName,         NSString,   issue[@"probstatename"]);
            GetValue(title,             NSString,   issue[@"problemTitle"]);
            GetValue(hidden,            NSNumber,   issue[@"hide"]);
            GetValue(description,       NSString,   issue[@"problemDescription"]);
            GetValue(origDateString,    NSString,   issue[@"whenOriginatedDate"]);
            
            /* The component name seems to be excluded on archived bug reports; in the case where it's missing,
             * provide a blank value. */
            NSString *componentName = [NSString ma_castRequiredObject: issue[@"compNameForWeb"]];
            if (componentName == nil)
                componentName = @"";

            /* Format the date */
            NSDate *origDate = [_dateFormatter dateFromString: origDateString];
            if (origDate == nil) {
                NSLog(@"Could not format date: %@", origDateString);
                NSError *parseError = [NSError pl_errorWithDomain: ANTErrorDomain
                                                             code: ANTErrorInvalidResponse
                                             localizedDescription: NSLocalizedString(@"Unable to parse the server result.", nil)
                                           localizedFailureReason: NSLocalizedString(@"Server sent an unexpected date format.", nil)
                                                  underlyingError: nil
                                                         userInfo: nil];
                handler(nil, parseError);
                return;
            }
            
            /* Clean up the summary; the first line is a radar comment attributeion, eg, '<GMT09-Aug-2013 21:14:47GMT> Landon Fuller:' */
            NSRange descriptionStart = [attributionLineRegex rangeOfFirstMatchInString: description options: 0 range: NSMakeRange(0, [description length])];
            if (descriptionStart.location != NSNotFound)
                description = [description substringFromIndex: NSMaxRange(descriptionStart)];

            ANTRadarSummaryResponse *summaryEntry;
            summaryEntry = [[ANTRadarSummaryResponse alloc] initWithRadarId: radarId
                                                                  stateName: stateName
                                                                      title: title
                                                              componentName: componentName
                                                                     hidden: [hidden boolValue]
                                                                description: description
                                                             originatedDate: origDate];
            [results addObject: summaryEntry];
        }
        
        handler(results, error);
    }];
}

/**
 * Issue a login request.
 *
 * @param account The account details, or nil to request that account details be supplied by the authentication
 * delegate.
 * @param password The password to use for login.
 * @param ticket A request cancellation ticket.
 * @param callback The callback to be called upon completion.
 */
- (void) loginWithAccount: (ANTNetworkClientAccount *) account
             cancelTicket: (PLCancelTicket *) ticket
          dispatchContext: (id<PLDispatchContext>) context
        completionHandler: (void (^)(NSError *error)) callback
{
    /* Automically update the auth state */
    OSSpinLockLock(&_lock); {
        if (_authState != ANTNetworkClientAuthStateLoggedOut) {
            OSSpinLockUnlock(&_lock);

            [context performWithCancelTicket: ticket block: ^{
                NSError *err = [NSError pl_errorWithDomain: ANTErrorDomain
                                                      code: ANTErrorRequestConflict
                                      localizedDescription: NSLocalizedString(@"Sign in failed.", nil)
                                    localizedFailureReason: NSLocalizedString(@"Attempted to sign in while already authenticated.", nil)
                                           underlyingError: nil
                                                  userInfo: nil];
                callback(err);
            }];
            return;
        }

        _authState = ANTNetworkClientAuthStateAuthenticating;
    } OSSpinLockUnlock(&_lock);
    
    /* Note the state change. There's no gaurantee of ordering here. */
    [_observers enumerateObserversRespondingToSelector: @selector(networkClientDidChangeAuthState:) block: ^(id observer) {
        [observer networkClientDidChangeAuthState: self];
    }];

    NSAssert(_authDelegate != nil, @"Missing authentication delegate; was it deallocated?");

    /* Issue the request */
    [_authDelegate networkClient: self authRequiredWithAccount: account cancelTicket: ticket andCall: ^(ANTNetworkClientAuthResult *result, NSError *error) {
        OSSpinLockLock(&_lock); {
            NSAssert(_authState == ANTNetworkClientAuthStateAuthenticating, @"Authentication state was changed for in-process authentication");
            if (error == nil) {
                _authState = ANTNetworkClientAuthStateAuthenticated;
            } else {
                _authState = ANTNetworkClientAuthStateLoggedOut;
            }

            _authResult = result;
        } OSSpinLockUnlock(&_lock);

        /* Inform the caller */
        callback(error);
        
        /* Note the state change. */
        [_observers enumerateObserversRespondingToSelector: @selector(networkClientDidChangeAuthState:) block: ^(id observer) {
            [observer networkClientDidChangeAuthState: self];
        }];
    }];
}

/**
 * Issue a logout request.
 */
- (void) logoutWithCancelTicket: (PLCancelTicket *) ticket dispatchContext: (id<PLDispatchContext>) context completionHandler: (void (^)(NSError *error)) callback {
    /* Automically update the auth state */
    OSSpinLockLock(&_lock); {
        if (_authState != ANTNetworkClientAuthStateAuthenticated) {
            OSSpinLockUnlock(&_lock);
            
            [context performWithCancelTicket: ticket block: ^{
                NSError *err = [NSError pl_errorWithDomain: ANTErrorDomain
                                                      code: ANTErrorRequestConflict
                                      localizedDescription: NSLocalizedString(@"Failed to sign out.", nil)
                                    localizedFailureReason: NSLocalizedString(@"Attempted to sign out while not logged in.", nil)
                                           underlyingError: nil
                                                  userInfo: nil];
                callback(err);
            }];
            return;
        }
        
        _authState = ANTNetworkClientAuthStateLoggingOut;
    } OSSpinLockUnlock(&_lock);

    /* Note the state change. */
    [_observers enumerateObserversRespondingToSelector: @selector(networkClientDidChangeAuthState:) block: ^(id observer) {
        [observer networkClientDidChangeAuthState: self];
    }];

    if (_authState != ANTNetworkClientAuthStateAuthenticated) {
        if (!ticket.isCancelled) {
            NSError *err = [NSError pl_errorWithDomain: ANTErrorDomain
                                                  code: ANTErrorRequestConflict
                                  localizedDescription: NSLocalizedString(@"Failed to sign out.", nil)
                                localizedFailureReason: NSLocalizedString(@"Attempted to sign out while not logged in.", nil)
                                       underlyingError: nil
                                              userInfo: nil];
            callback(err);
        }
            
        return;
    }
    
    NSAssert(_authDelegate != nil, @"Missing authentication delegate; was it deallocated?");
    
    NSURL *url = [NSURL URLWithString: @"/logout" relativeToURL: [ANTNetworkClient bugReporterURL]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL: url];

    /* CSRF handling */
    [req addValue: _authResult.csrfToken forHTTPHeaderField:@"csrftokencheck"];
    
    /* Try to make the headers look more like the browser */
    [req setValue: [[ANTNetworkClient bugReporterURL] absoluteString] forHTTPHeaderField: @"Origin"];
    
    /* Disable caching */
    [req setCachePolicy: NSURLCacheStorageNotAllowed];
    [req addValue: @"no-cache" forHTTPHeaderField: @"Cache-Control"];
    
    /* We need cookies for session and authentication verification done by the server */
    [req setHTTPShouldHandleCookies: YES];
    
    [NSURLConnection pl_sendAsynchronousRequest: req queue: _opQueue cancelTicket: ticket completionHandler:^(NSURLResponse *resp, NSData *data, NSError *error) {
        if (error != nil) {
            /* Reset to the authenticated state. This may not be true, but we can retry logout
             * from within that state */
            OSSpinLockLock(&_lock); {
                _authState = ANTNetworkClientAuthStateAuthenticated;
            } OSSpinLockUnlock(&_lock);

            /* Inform the caller of the failure */
            [context performWithCancelTicket: ticket block: ^{
                NSError *err = [NSError pl_errorWithDomain: ANTErrorDomain
                                                      code: ANTErrorConnectionLost
                                      localizedDescription: [error localizedDescription]
                                    localizedFailureReason: [error localizedFailureReason]
                                           underlyingError: error
                                                  userInfo: nil];
                callback(err);
            }];
            return;
        }
        
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *) resp;
        if ([httpResp statusCode] != 200) {
            [context performWithCancelTicket: ticket block:^{
                NSError *err = [NSError pl_errorWithDomain: ANTErrorDomain
                                                      code: ANTErrorInvalidResponse
                                      localizedDescription: NSLocalizedString(@"The server request failed.", nil)
                                    localizedFailureReason: [NSString stringWithFormat: NSLocalizedString(@"The server returned an error response (%zd)", nil), [httpResp statusCode]]
                                           underlyingError: nil
                                                  userInfo: nil];
                callback(err);
            }];
            return;
        }
        
        /* Otherwise, success! */
        OSSpinLockLock(&_lock); {
            _authResult = nil;
            _authState = ANTNetworkClientAuthStateLoggedOut;
        } OSSpinLockUnlock(&_lock);

        [context performWithCancelTicket: ticket block: ^{
            callback(nil);
        }];

        /* Note the state change. */
        [_observers enumerateObserversRespondingToSelector: @selector(networkClientDidChangeAuthState:) block: ^(id observer) {
            [observer networkClientDidChangeAuthState: self];
        }];
    }];
    
    /* On cancellation, reset the auth state. Any potential A->B->A condition is prevented
     * by the state preconditions require to change _authState; eg, it shouldn't be possible to trigger
     * a login event before logout has completed. */
    [ticket addCancelHandler:^(PLCancelTicketReason reason) {
        NSAssert(_authState == ANTNetworkClientAuthStateLoggingOut, @"Authentication state was changed for in-process sign out");

        if (_authState == ANTNetworkClientAuthStateLoggingOut)
            _authState = ANTNetworkClientAuthStateLoggedOut;
    } dispatchContext: [PLGCDDispatchContext mainQueueContext]];
}

/**
 * Post JSON request data @a json to @a resourcePath, calling @a completionHandler on finish.
 *
 * @param json A foundation instance that may be represented as JSON
 * @param resourcePath The resource path to which the JSON data will be POSTed.
 * @param ticket A request cancellation ticket.
 * @param context The dispatch context on which the result @a handler will be called.
 * @param handler The block to call upon completion. If an error occurs, error will be non-nil. On success, the JSON response data
 * will be provided via jsonData.
 *
 * @todo Implement handling of the standard JSON error results.
 */
- (void) postJSON: (id) json
           toPath: (NSString *) resourcePath
     cancelTicket: (PLCancelTicket *) ticket
  dispatchContext: (id<PLDispatchContext>) context
completionHandler: (void (^)(id jsonData, NSError *error)) handler
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject: json options: 0 error: &error];
    NSAssert(jsonData != nil, @"Invalid JSON request data");

    /* Formulate the POST */
    NSURL *url = [NSURL URLWithString: resourcePath relativeToURL: [ANTNetworkClient bugReporterURL]];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL: url];
    [req setHTTPMethod: @"POST"];
    [req setHTTPBody: jsonData];
    [req setValue: @"application/json; charset=UTF-8" forHTTPHeaderField: @"Content-Type"];

    /* CSRF handling */
    [req addValue: _authResult.csrfToken forHTTPHeaderField:@"csrftokencheck"];

    /* Try to make the headers look more like the browser */
    [req setValue: [[ANTNetworkClient bugReporterURL] absoluteString] forHTTPHeaderField: @"Origin"];
    [req setValue: @"XMLHTTPRequest" forHTTPHeaderField: @"X-Requested-With"];
    
    /* Disable caching */
    [req setCachePolicy: NSURLCacheStorageNotAllowed];
    [req addValue: @"no-cache" forHTTPHeaderField: @"Cache-Control"];

    /* We need cookies for session and authentication verification done by the server */
    [req setHTTPShouldHandleCookies: YES];
    
    /* Issue the request */
    [NSURLConnection pl_sendAsynchronousRequest: req queue: _opQueue cancelTicket: ticket completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        /* Perform the handler callback on the right dispatch context, checking for cancellation */
        void (^performHandler)(id, NSError *) = ^(id value, NSError *error) {
            [context performBlock:^{
                if (!ticket.isCancelled)
                    handler(value, error);
            }];
        };
        
        if (error != nil) {
            NSError *antError = [NSError pl_errorWithDomain: ANTErrorDomain
                                                       code: ANTErrorInvalidResponse
                                       localizedDescription: NSLocalizedString(@"Unable to parse the server result", nil)
                                     localizedFailureReason: NSLocalizedString(@"Server sent invalid JSON data", nil)
                                            underlyingError: error
                                                   userInfo: nil];
            performHandler(nil, antError);
            return;
        }
        
        /* Parse the result. TODO: Generic handling of JSON isError results */
        NSError *jsonError;
        id jsonResult = [NSJSONSerialization JSONObjectWithData: data options:0 error: &jsonError];
        if (jsonResult == nil) {
            NSError *antError = [NSError pl_errorWithDomain: ANTErrorDomain
                                                       code: ANTErrorInvalidResponse
                                       localizedDescription: NSLocalizedString(@"Unable to parse the server result", nil)
                                     localizedFailureReason: NSLocalizedString(@"Server sent invalid JSON data", nil)
                                            underlyingError: jsonError
                                                   userInfo: nil];
            
            performHandler(nil, antError);
            handler(nil, error);
            return;
        }
    
         performHandler(jsonResult, nil);
    }];
}

@end
