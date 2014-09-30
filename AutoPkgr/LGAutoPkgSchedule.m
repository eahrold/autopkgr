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

@implementation LGAutoPkgSchedule

+ (void)startAutoPkgSchedule:(BOOL)start interval:(NSInteger)interval isForced:(BOOL)forced reply:(void (^)(NSError* error))reply;
{
    BOOL scheduleIsRunning = jobIsRunning(kLGAutoPkgrLaunchDaemonPlist, kAHGlobalLaunchDaemon);
    if (start && interval == 0) {
        reply([LGError errorWithCode:kLGErrorIncorrectScheduleTimerInterval]);
        return;
    }
    
    // Create the external form authorization data for the helper
    NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
    assert(authorization != nil);
    
    LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
    [helper connectToHelper];
    
    if (start && (!scheduleIsRunning || forced)) {
        
        // Convert seconds to hours for our time interval
        NSTimeInterval runInterval = interval * 60 * 60;
        NSString *program = [[NSProcessInfo processInfo] arguments].firstObject;

        [[helper.connection remoteObjectProxy] scheduleRun:runInterval user:NSUserName() program:program authorization:authorization reply:^(NSError *error) {
            NSDate *date = [NSDate dateWithTimeIntervalSinceNow:runInterval];
            NSDateFormatter *fomatter = [NSDateFormatter new];
            [fomatter setDateStyle:NSDateFormatterMediumStyle];
            [fomatter setTimeStyle:NSDateFormatterMediumStyle];
            NSLog(@"Next scheduled AutoPkg run will occur at %@",[fomatter stringFromDate:date]);
            reply(error);
        }];
    } else if (scheduleIsRunning) {
        [[helper.connection remoteObjectProxy] removeScheduleWithAuthorization:authorization reply:^(NSError *error) {
            reply(error);
        }];
    }
}


@end
