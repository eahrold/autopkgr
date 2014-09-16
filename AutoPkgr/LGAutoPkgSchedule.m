//
//  LGAutoPkgSchedule.m
//  AutoPkgr
//
//  Created by Eldon on 9/6/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGAutoPkgSchedule.h"
#import "LGAutoPkgr.h"
#import <AHLaunchCtl/AHLaunchCtl.h>
#import "LGAutoPkgrHelperConnection.h"

@implementation LGAutoPkgSchedule {
    NSTimer *_timer;
}

+(BOOL)scheduleIsRunning{
    return jobIsRunning(kLGAutoPkgrLaunchDaemonPlist, kAHGlobalLaunchDaemon);
}

- (void)startAutoPkgSchedule:(BOOL)start isForced:(BOOL)forced reply:(void (^)(NSError* error))reply;
{
    LGDefaults *defaults = [[LGDefaults alloc] init];
    
    BOOL scheduleIsRunning = jobIsRunning(kLGAutoPkgrLaunchDaemonPlist, kAHGlobalLaunchDaemon);
    
    // Create the external form authorization data for the helper
    NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
    assert(authorization != nil);
    
    LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
    [helper connectToHelper];
    
    if (start && (!scheduleIsRunning || forced)) {
        
        NSString *program = [[NSProcessInfo processInfo] arguments].firstObject;
        
        [[helper.connection remoteObjectProxy] scheduleRun:defaults.autoPkgRunInterval user:NSUserName() program:program authorization:authorization reply:^(NSError *error) {
            reply(error);
        }];
    } else if (scheduleIsRunning) {
        [[helper.connection remoteObjectProxy] removeScheduleWithAuthorization:authorization reply:^(NSError *error) {
            reply(error);
        }];
    }
}


@end
