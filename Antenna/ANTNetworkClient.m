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
 * Notification dispatched on successful login. The notification object will
 * be the authenticated network client instance.
 */
NSString *NetworkClientDidLoginNotification = @"NetworkClientDidLoginNotification";


@interface ANTNetworkClient ()
- (void) postJSON: (id) json toPath: (NSString *) resourcePath completionHandler: (void (^)(id jsonData, NSError *error)) handler;
@end

@implementation ANTNetworkClient {
@private
    /** Base URL for all requests. */
    NSURL *_bugReporterURL;

    /** YES if authenticated, NO otherwise */
    BOOL _isAuthenticated;

    /** The backing authentication delegate */
    __weak id<ANTNetworkClientAuthDelegate> _authDelegate;

    /** The authentication result, if available. Nil if authentication has not completed or has been invalidated. */
    ANTNetworkClientAuthResult *_authResult;

    /** Date formatter to use for report dates (DD-MON-YYYY HH:MM) */
    NSDateFormatter *_dateFormatter;
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
    
    _authDelegate = authDelegate;
    
    /* Use the default remote URL */
    _bugReporterURL = [ANTNetworkClient bugReporterURL];

    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"dd-MMM-yyyy HH:mm"];
    [_dateFormatter setLocale: [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];

    return self;
}

/**
 * Request all radar issue summaries for @a sectionName.
 *
 * @param sectionName The section name.
 * @param completionHandler The block to call upon completion. If an error occurs, error will be non-nil. The summaries
 * will be provided as an ordered array of ANTRadarSummaryResponse values.
 *
 * @todo Define constants for supported sections ('Open', etc).
 * @todo Implement paging support.
 * @todo Allow for specifying the sort order.
 * @todo Implement cancellation support (return a cancellation ticket?).
 */
- (void) requestSummariesForSection: (NSString *) sectionName completionHandler: (void (^)(NSArray *summaries, NSError *error)) handler {
    NSDictionary *req = @{@"reportID" : sectionName, @"orderBy" : @"DateOriginated,Descending", @"rowStartString":@"1" };
    [self postJSON: req toPath: @"/developer/problem/getSectionProblems" completionHandler:^(id jsonData, NSError *error) {
        /* Verify the response type */
        if (![jsonData isKindOfClass: [NSDictionary class]]) {
            handler(nil, [NSError errorWithDomain: NSCocoaErrorDomain code: NSURLErrorCannotParseResponse userInfo: nil]);
            return;
        }
    
        /* Parse out the data */
        MAErrorReportingDictionary *jsonDict = [[MAErrorReportingDictionary alloc] initWithDictionary: jsonData];
        id (^Check)(id) = ^(id value) {
            if (value == nil) {
                handler(nil, [jsonDict error]);
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
            GetValue(componentName,     NSString,   issue[@"compNameForWeb"]);
            GetValue(hidden,            NSNumber,   issue[@"hide"]);
            GetValue(description,       NSString,   issue[@"problemDescription"]);
            GetValue(origDateString,    NSString,   issue[@"whenOriginatedDate"]);

            /* Format the date */
            NSDate *origDate = [_dateFormatter dateFromString: origDateString];
            if (origDate == nil) {
                NSLog(@"Could not format date: %@", origDateString);
                handler(nil, [NSError errorWithDomain: NSCocoaErrorDomain code: NSURLErrorCannotParseResponse userInfo: nil]);
                return;
            }
            
            /* Clean up the summary; the first line is a radar comment attributeion, eg, '<GMT09-Aug-2013 21:14:47GMT> Landon Fuller:' */
            NSRange descriptionStart = [attributionLineRegex rangeOfFirstMatchInString: description options: 0 range: NSMakeRange(0, [description length])];
            if (descriptionStart.location != NSNotFound)
                description = [description substringFromIndex: NSMaxRange(descriptionStart)];

            ANTRadarSummaryResponse *summaryEntry;
            summaryEntry = [[ANTRadarSummaryResponse alloc] initWithRadarId: [radarId stringValue]
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
 * Issue a login request. This will display an embedded WebKit window.
 */
- (void) login {
    if (self.isAuthenticated)
        return;
    
    NSAssert(_authDelegate != nil, @"Missing authentication delegate; was it deallocated?");

    // TODO - utilize cancellation?
    [_authDelegate networkClient: self authRequiredWithCancelTicket: [PLCancelTicketSource new].ticket andCall:^(ANTNetworkClientAuthResult *result, NSError *error) {
        _isAuthenticated = YES;
        _authResult = result;
        [[NSNotificationCenter defaultCenter] postNotificationName: NetworkClientDidLoginNotification object: self];
    }];
}

// property getter
- (BOOL) isAuthenticated {
    return _isAuthenticated;
}

/**
 * Post JSON request data @a json to @a resourcePath, calling @a completionHandler on finish.
 *
 * @param json A foundation instance that may be represented as JSON
 * @param resourcePath The resource path to which the JSON data will be POSTed.
 * @param handler The block to call upon completion. If an error occurs, error will be non-nil. On success, the JSON response data
 * will be provided via jsonData.
 *
 * @todo Implement handling of the standard JSON error results.
 */
- (void) postJSON: (id) json toPath: (NSString *) resourcePath completionHandler: (void (^)(id jsonData, NSError *error)) handler {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject: json options: 0 error: &error];
    if (jsonData == nil)
        handler(nil, error);

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
    [NSURLConnection sendAsynchronousRequest: req queue: [NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *error) {
        if (error != nil) {
            handler(nil, error);
            return;
        }
        
        /* Parse the result. TODO: Generic handling of JSON isError results */
        NSError *jsonError;
        id jsonResult = [NSJSONSerialization JSONObjectWithData: data options:0 error: &jsonError];
        if (jsonResult == nil) {
            handler(nil, jsonError);
            return;
        }
    
         handler(jsonResult, nil);
    }];
}

@end
