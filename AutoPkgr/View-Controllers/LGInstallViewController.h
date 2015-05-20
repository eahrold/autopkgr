//
//  LGInstallViewController.h
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LGProgressDelegate.h"

@interface LGInstallViewController : NSViewController

- (instancetype)initWithProgressDelegate:(id<LGProgressDelegate>)progressDelegate;
@property (weak) id<LGProgressDelegate>progressDelegate;

@property (weak) IBOutlet NSButton *installGitButton;
@property (weak) IBOutlet NSButton *installAutoPkgButton;

// Labels
@property (weak) IBOutlet NSTextField *gitStatusLabel;
@property (weak) IBOutlet NSTextField *autoPkgStatusLabel;

@property (weak) IBOutlet NSButton *launchAtLoginButton;

// Display Mode settings
@property (weak) IBOutlet NSButton *hideInDock;
@property (weak) IBOutlet NSButton *showInMenuButton;
@property (weak) IBOutlet NSTextField *restartRequiredLabel;

// Status icons
@property (weak) IBOutlet NSImageView *gitStatusIcon;
@property (weak) IBOutlet NSImageView *autoPkgStatusIcon;

@end
