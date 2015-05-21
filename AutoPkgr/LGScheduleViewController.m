//
//  LGScheduleViewController.m
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGScheduleViewController.h"
#import "LGPasswords.h"
#import "LGAutoPkgr.h"
#import "LGAutoPkgSchedule.h"
#import "LGEmailer.h"
#import "LGTestPort.h"
#import "LGAutoPkgTask.h"
#import "LGAutoPkgRecipe.h"

@interface LGScheduleViewController () {
    LGDefaults *_defaults;
    LGAutoPkgTaskManager *_taskManager;
}

@end

@implementation LGScheduleViewController

- (void)awakeFromNib {
    // Set up schedule settings
    NSInteger timer;
    _scheduleEnabledBT.state = [LGAutoPkgSchedule updateAppsIsScheduled:&timer];
    _scheduleIntervalTF.integerValue = timer;
    _scheduleMenuItem.enabled = _scheduleEnabledBT.state;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

#pragma mark - Accessors
- (void)setScheduleMenuItem:(NSMenuItem *)scheduleMenuItem {
    scheduleMenuItem.target = self;
    scheduleMenuItem.action = @selector(changeSchedule:);
    _scheduleMenuItem = scheduleMenuItem;
}

- (void)setCancelButton:(NSButton *)cancelButton {
    cancelButton.target = self;
    cancelButton.action = @selector(cancelAutoPkgRun:);
    _cancelButton = cancelButton;
}

#pragma mark - State Actions
- (IBAction)changeSchedule:(id)sender
{
    NSLog(@"Change Schedule in view action...");

    NSInteger scheduledInterval;
    BOOL currentlyScheduled = [LGAutoPkgSchedule updateAppsIsScheduled:&scheduledInterval];

    BOOL start = currentlyScheduled;
    if (![sender isEqualTo:_scheduleIntervalTF]) {
        if ([sender isKindOfClass:[NSMenuItem class]]) {
            start = [sender isEnabled];
        } else {
            start = [sender state];
        }
    }

    BOOL force = NO;
    NSInteger interval = _scheduleIntervalTF.integerValue;

    if ([sender isEqualTo:_scheduleIntervalTF]) {
        if (!start || scheduledInterval == interval) {
            return;
        }
        // We set force here so it will reload the schedule
        // if it is currently enabled
        force = YES;
    }

    NSLog(@"%@ autopkg run schedule.", currentlyScheduled ? @"Enabling" : @"Disabling");
    [LGAutoPkgSchedule startAutoPkgSchedule:start interval:interval isForced:force reply:^(NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSInteger timer;
            BOOL currentlyScheduled = [LGAutoPkgSchedule updateAppsIsScheduled:&timer];
            _scheduleMenuItem.state = currentlyScheduled;
            _scheduleEnabledBT.state = currentlyScheduled;

            if (error) {
                // If error, reset the state to modified status
                _scheduleIntervalTF.stringValue = [@(timer) stringValue];

                // If the authorization was canceled by user, don't present error.
                if (error.code != kLGErrorAuthChallenge) {
                    [self.progressDelegate stopProgress:error];
                }
            } else {

                NSString *menuItemTitle = [NSString stringWithFormat:@"Run AutoPkg Every %ld Hours", interval];
                [_scheduleMenuItem setTitle:menuItemTitle];
            }
        }];
    }];
}


#pragma mark - AutoPkg actions

- (IBAction)updateReposNow:(id)sender
{

    _cancelButton.hidden = NO;
    [self.progressDelegate startProgressWithMessage:@"Updating AutoPkg recipe repos."];

    [_updateRepoNowButton setEnabled:NO];
    if (!_taskManager) {
        _taskManager = [[LGAutoPkgTaskManager alloc] init];
    }

    _taskManager.progressDelegate = self.progressDelegate;

    [_taskManager repoUpdate:^(NSError *error) {
        NSAssert([NSThread isMainThread], @"Reply not on main thread!");
        [self.progressDelegate stopProgress:error];
        _updateRepoNowButton.enabled = YES;
    }];
}

- (IBAction)checkAppsNow:(id)sender
{
    NSString *recipeList = [LGAutoPkgRecipe defaultRecipeList];
    _cancelButton.hidden = NO;
    if (!_taskManager) {
        _taskManager = [[LGAutoPkgTaskManager alloc] init];
    }

    _taskManager.progressDelegate = self.progressDelegate;

    [self.progressDelegate startProgressWithMessage:@"Running selected AutoPkg recipes..."];

    [_taskManager runRecipeList:recipeList
                     updateRepo:NO
                          reply:^(NSDictionary *report, NSError *error) {
                              NSAssert([NSThread isMainThread], @"Reply not on main thread!");

                              [self.progressDelegate stopProgress:error];
                              if (report.count || error) {
                                  LGEmailer *emailer = [LGEmailer new];

                                  emailer.replyBlock = ^(NSError *error){
                                      [self.progressDelegate stopProgress:error];
                                  };

                                  [emailer sendEmailForReport:report error:error];
                              }
                          }];
}

- (IBAction)cancelAutoPkgRun:(id)sender
{
    if (_taskManager) {
        [_taskManager cancel];
    }
}

@end
