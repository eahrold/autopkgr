//
//  LGInstallViewController.m
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGInstallViewController.h"
#import "LGAutoPkgSchedule.h"
#import "LGAutoPkgr.h"
#import "LGToolStatus.h"
#import "LGDisplayStatusDelegate.h"

@interface LGInstallViewController (){
    LGAutoPkgTool *_autoPkgTool;
    LGGitTool *_gitTool;
}

@end

@implementation LGInstallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib {
    LGDefaults *_defaults = [LGDefaults standardUserDefaults];
    // Set launch at login button
    _launchAtLoginButton.state = [LGAutoPkgSchedule willLaunchAtLogin];

    // Set display mode button
    LGApplicationDisplayStyle displayStyle = _defaults.applicationDisplayStyle;

    _hideInDock.state = !(displayStyle & kLGDisplayStyleShowDock);
    _showInMenuButton.state = (displayStyle & kLGDisplayStyleShowMenu);

    // Check to see what's installed, and what needs updating
    [self refreshToolsStatus:self];

}

- (IBAction)changeDisplayMode:(NSButton *)sender
{
    NSApplication *app = [NSApplication sharedApplication];

    LGApplicationDisplayStyle newStyle = kLGDisplayStyleShowNone;

    if (!_hideInDock.state) {
        newStyle = kLGDisplayStyleShowDock;
    }

    if (_showInMenuButton.state) {
        newStyle = newStyle | kLGDisplayStyleShowMenu;
    }

    [[LGDefaults standardUserDefaults] setApplicationDisplayStyle:newStyle];

    if ([sender isEqualTo:_hideInDock]) {
        _restartRequiredLabel.hidden = !sender.state;
        if (!sender.state) {
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        }
    }

    if ([sender isEqualTo:_showInMenuButton]) {
        if ([app.delegate respondsToSelector:@selector(showStatusMenu:)]) {
            [app.delegate performSelector:@selector(showStatusMenu:) withObject:@(_showInMenuButton.state)];
        }
    }
}

- (void)refreshToolsStatus:(id)sender
{
    if (!_autoPkgTool) {
        _autoPkgTool = [[LGAutoPkgTool alloc] init];
        _autoPkgTool.progressDelegate = self.progressDelegate;
        _installAutoPkgButton.target = _autoPkgTool;
    }

    [_autoPkgTool getInfo:^(LGToolInfo *info) {
        _installAutoPkgButton.enabled = info.needsInstalled;
        _installAutoPkgButton.title = info.installButtonTitle;
        _autoPkgStatusIcon.image = info.statusImage;
        _autoPkgStatusLabel.stringValue = info.statusString;
        _installAutoPkgButton.action = info.targetAction;
    }];

    if (!_gitTool) {
        _gitTool = [[LGGitTool alloc] init];
        _gitTool.progressDelegate = self.progressDelegate;
        _installGitButton.target = _gitTool;
    }

    [_gitTool getInfo:^(LGToolInfo *info) {
        _installGitButton.enabled = info.needsInstalled;
        _installGitButton.title = info.installButtonTitle;
        _gitStatusLabel.stringValue = info.statusString;
        _gitStatusIcon.image = info.statusImage;
        _installGitButton.action = info.targetAction;
    }];
}
@end
