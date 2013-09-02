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

#import "AntennaAppDelegate.h"
#import "ANTSummaryWindowController.h"

@implementation AntennaAppDelegate {
@private
    /** Summary window controller */
    IBOutlet ANTSummaryWindowController *_summaryWindowController;
}

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification {
    /* Set up client and start login */
    _networkClient = [[ANTNetworkClient alloc] init];
    [_networkClient login];

    /* Wait for completion, and then fire up our summary window */
    [[NSNotificationCenter defaultCenter] addObserverForName:  RATNetworkClientDidLoginNotification object: _networkClient queue: [NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [_summaryWindowController showWindow: nil];
    }];
}

@end
