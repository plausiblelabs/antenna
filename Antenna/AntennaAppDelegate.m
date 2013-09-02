//
//  PLAppDelegate.m
//  Antenna
//
//  Created by Landon Fuller on 9/1/13.
//  Copyright (c) 2013 Plausible Labs. All rights reserved.
//

#import "AntennaAppDelegate.h"
#import "ANTNetworkClient.h"

@implementation AntennaAppDelegate {
@private
    ANTNetworkClient *_networkClient;
}

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification {
    _networkClient = [[ANTNetworkClient alloc] init];
    [_networkClient login];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:  RATNetworkClientDidLoginNotification object: _networkClient queue: [NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [_networkClient requestSummariesForSection: @"Open" completionHandler: ^(NSArray *summaries, NSError *error) {
            NSLog(@"Summaries: %@", summaries);
        }];
    }];
}

@end
