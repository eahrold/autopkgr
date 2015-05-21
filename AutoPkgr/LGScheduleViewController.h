//
//  LGScheduleViewController.h
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LGBaseViewController.h"

@interface LGScheduleViewController : LGBaseViewController

#pragma mark - Schedule
#pragma mark -- Outlets --
@property (weak) IBOutlet NSTextField *scheduleIntervalTF;
@property (weak) IBOutlet NSButton *scheduleEnabledBT;

@property (weak) IBOutlet NSButton *runAutoPkgNowButton;
@property (weak) IBOutlet NSButton *updateRepoNowButton;

// These are set externally and not part of the LGScheduleViewController.xib
@property (weak, nonatomic) NSButton *cancelButton;
@property (weak, nonatomic) NSMenuItem *scheduleMenuItem;


#pragma mark -- IBActions --
- (IBAction)changeSchedule:(id)sender;
- (IBAction)updateReposNow:(id)sender;
- (IBAction)checkAppsNow:(id)sender;
- (void)cancelAutoPkgRun:(id)sender;


@end
