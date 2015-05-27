//
//  LGNotificationsViewController.h
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LGBaseTabViewController.h"

@interface LGNotificationsViewController : LGBaseTabViewController

#pragma mark - Email
#pragma mark -- Outlets --

@property (weak) IBOutlet NSTextField *smtpServer;
@property (weak) IBOutlet NSTextField *smtpPort;

@property (weak) IBOutlet NSTextField *smtpUsername;
@property (weak) IBOutlet NSSecureTextField *smtpPassword;


// Status icons
@property (weak) IBOutlet NSImageView *testSmtpServerStatus;

// Spinners
@property (weak) IBOutlet NSProgressIndicator *sendTestEmailSpinner;
@property (weak) IBOutlet NSProgressIndicator *testSmtpServerSpinner;

#pragma mark -- IBActions --
- (IBAction)sendTestEmail:(id)sender;
- (IBAction)testServerPort:(id)sender;

- (IBAction)getKeychainPassword:(NSTextField *)sender;
- (IBAction)updateKeychainPassword:(id)sender;

@end
