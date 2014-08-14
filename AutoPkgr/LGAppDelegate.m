//
//  LGAppDelegate.m
//  AutoPkgr
//
//  Created by James Barclay on 6/25/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

#import "LGAppDelegate.h"
#import "LGConstants.h"
#import "LGAutoPkgrHelperConnection.h"
#import "LGConfigurationWindowController.h"
#import "AHLaunchCTL.h"

@implementation LGAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Setup the status item
    [self setupStatusItem];

    // Check if we're authorized to install helper tool,
    // if not just quit
    NSError *error;
    if (![AHLaunchCtl installHelper:kAutoPkgrHelperToolName prompt:@"To schedule" error:&error]) {
        if (error) {
            NSLog(@"%@", error.localizedDescription);
            [NSApp presentError:[NSError errorWithDomain:kApplicationName code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"The associated helper tool could not be installed, we must now quit" }]];
            [[NSApplication sharedApplication] terminate:self];
        }
    }

    // Show the configuration window if we haven't
    // completed the initial setup
    if ([defaults objectForKey:kHasCompletedInitialSetup]) {

        BOOL hasCompletedInitialSetup = [[defaults objectForKey:kHasCompletedInitialSetup] boolValue];

        if (!hasCompletedInitialSetup) {
            [self showConfigurationWindow:nil];
        }
    } else {
        [self showConfigurationWindow:nil];
    }

    // Update AutoPkg recipe repos when the application launches
    // if the user has enabled automatic repo updates
    if ([defaults boolForKey:kCheckForRepoUpdatesAutomaticallyEnabled]) {
        NSLog(@"Updating AutoPkg recipe repos.");
        [self updateAutoPkgRecipeReposInBackgroundAtAppLaunch];
    }
}

- (void)updateAutoPkgRecipeReposInBackgroundAtAppLaunch
{
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [autoPkgRunner invokeAutoPkgRepoUpdateInBackgroundThread];
}

- (void)setupStatusItem
{
    // Setup the systemStatusBar
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setMenu:self.statusMenu];
    [self.statusItem setImage:[NSImage imageNamed:@"autopkgr.png"]];
    [self.statusItem setAlternateImage:[NSImage imageNamed:@"autopkgr_alt.png"]];
    [self.statusItem setHighlightMode:YES];
    self.statusItem.menu = self.statusMenu;
}

- (void)checkNowFromMenu:(id)sender
{
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [autoPkgRunner invokeAutoPkgInBackgroundThread];
}

- (void)showConfigurationWindow:(id)sender
{
    if (!self->configurationWindowController) {
        self->configurationWindowController = [[LGConfigurationWindowController alloc] initWithWindowNibName:@"LGConfigurationWindowController"];
    }

    [NSApp activateIgnoringOtherApps:YES];
    [self->configurationWindowController.window makeKeyAndOrderFront:nil];
}

- (IBAction)uninstallHelper:(id)sender
{
    LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
    [helper connectToHelper];
    [[helper.connection remoteObjectProxy] uninstall:^(NSError *error) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if(error){
                    [NSApp presentError:error];
            } else {
                NSError *error;
                if(![AHLaunchCtl uninstallHelper:kAutoPkgrHelperToolName prompt:@"Authorize removal of the Helper tool.  " error:&error]){
                    [NSApp presentError:error];
                }else{
                    // if uninstalling turn off schedule in defaults so it's not automatically recreated
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kCheckForNewVersionsOfAppsAutomaticallyEnabled];
                    NSAlert *alert = [NSAlert alertWithMessageText:@"Removed AutoPkgr Associated files" defaultButton:@"Thanks for using AutoPkgr" alternateButton:nil otherButton:nil informativeTextWithFormat: @"including the helper tool, launchd schedule, and other launchd plist.  You can safely remove it from your Application Folder"];
                    [alert runModal];
                    [[NSApplication sharedApplication]terminate:self];
                }
            }
        }];
    }];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if (jobIsRunning(kAutoPkgrHelperToolName, kAHGlobalLaunchDaemon)) {
        LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
        [helper connectToHelper];
        [[helper.connection remoteObjectProxy] quitHelper:^(BOOL success) {}];
    }
}

@end
