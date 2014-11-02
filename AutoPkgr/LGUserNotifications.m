// LGUserNotifications.m
//
// Copyright 2014 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGUserNotifications.h"
#import "LGAutoPkgr.h"

@implementation LGUserNotifications

+ (void)sendNotificationOfTestEmailSuccess:(BOOL)success error:(NSError *)error
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Email test completed.";
    notification.informativeText = success ? @"Successfully sent test email. Check your inbox to confirm" : @"There was a problem sending test email. Check your settings.";

    if (error) {
        [notification setUserInfo:@{kLGNotificationUserInfoError:error}];
        [notification setActionButtonTitle:@"Show Error"];
        [notification setOtherButtonTitle:@"Dismiss"];
    }


    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#pragma mark - NSUserNotificationDelegate
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    NSError *error = notification.userInfo[kLGNotificationUserInfoError];
    if (notification.activationType == NSUserNotificationActivationTypeActionButtonClicked) {
        [NSApp presentError:error];
    }
    
    [center removeDeliveredNotification:notification];
}

@end
