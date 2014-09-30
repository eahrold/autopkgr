//
//  LGAutoPkgSchedule.h
//  AutoPkgr
//
//  Created by Eldon on 9/6/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LGProgressDelegate.h"

@interface LGAutoPkgSchedule : NSObject

+ (void)startAutoPkgSchedule:(BOOL)start interval:(NSInteger)interval isForced:(BOOL)forced reply:(void (^)(NSError* error))reply;

@end
