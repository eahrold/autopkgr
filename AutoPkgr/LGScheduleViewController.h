//
//  LGScheduleViewController.h
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LGBaseTabViewController.h"

@class LGAutoPkgTaskManager;
@interface LGScheduleViewController : LGBaseTabViewController

#pragma mark - Schedule
#pragma mark-- Outlets --
@property (weak) IBOutlet NSMatrix* scheduleTypeMatrix;
@property (weak) IBOutlet NSTextField* scheduleIntervalTF;
@property (weak) IBOutlet NSButton* scheduleEnabledBT;

@property (weak) IBOutlet NSPopUpButton* dailyHourPopupBT;
@property (weak) IBOutlet NSPopUpButton* weeklyHourPopupBT;
@property (weak) IBOutlet NSPopUpButton* weeklyDayPopupBT;



@property (weak) IBOutlet NSButton* runAutoPkgNowButton;
@property (weak) IBOutlet NSButton* updateRepoNowButton;

/* These are set externally and not part of the
 * LGScheduleViewController.xib. Currently the cancel button
 * is referenced by LGConfigurationWindowController's progress panel.
 * The scheduleMenuItem is referenced by the status menu item. */
@property (weak, nonatomic) NSButton* cancelButton;
@property (weak, nonatomic) NSMenuItem* scheduleMenuItem;

#pragma mark-- IBActions --
- (IBAction)changeSchedule:(id)sender;
- (IBAction)updateReposNow:(id)sender;
- (IBAction)checkAppsNow:(id)sender;
- (void)cancelAutoPkgRun:(id)sender;

@end
