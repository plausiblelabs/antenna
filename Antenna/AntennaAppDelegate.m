//
//  PLAppDelegate.m
//  Antenna
//
//  Created by Landon Fuller on 9/1/13.
//  Copyright (c) 2013 Plausible Labs. All rights reserved.
//

#import "AntennaAppDelegate.h"
#import "RATNetworkClient.h"

@implementation AntennaAppDelegate {
@private
    RATNetworkClient *_networkClient;
}

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification {
    _networkClient = [[RATNetworkClient alloc] init];
    [_networkClient login];
}

@end
