//
//  LGConfigurationWindowController.m
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGConfigurationWindowController.h"
#import "LGAutoPkgr.h"
#import "LGProgressDelegate.h"
#import "LGToolManager.h"

@interface LGConfigurationWindowController () {
    LGToolManager *_toolManager;
    BOOL _awake;
}

@property (weak) IBOutlet NSTabView *tabViews;
@end

@implementation LGConfigurationWindowController

#pragma mark - init/dealloc/nib

- (instancetype)init {
    if (self = [super initWithWindowNibName:NSStringFromClass([self class])]) {

        _installView = [[LGInstallViewController alloc] initWithProgressDelegate:self];
        _scheduleView = [[LGScheduleViewController alloc] initWithProgressDelegate:self];
        _recipeRepoView = [[LGRecipeReposViewController alloc] initWithProgressDelegate:self];
        _notificationView = [[LGNotificationsViewController alloc] initWithProgressDelegate:self];
        _toolsView = [[LGToolsViewController alloc] initWithProgressDelegate:self];

        // The toolManager is required for the following views.
        _toolManager = [[LGToolManager alloc] init];
        _installView.toolManager = _toolManager;
        _toolsView.toolManager = _toolManager;
    }
    return self;
}

- (instancetype)initWithProgressDelegate:(id<LGProgressDelegate>)progressDelegate {
    if (self = [self init]) {
        /* In the main init method, the progress delegate is set as self by default,
         * but with the installView and schedule view want their progress delegate  */
        _installView.progressDelegate = progressDelegate;
        _scheduleView.progressDelegate = progressDelegate;
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)awakeFromNib {
    if (!_awake) {
        // Awake from nib can get called multiple times, but happens early,
        // So add code here that you want executed prior to the window showing.
        _awake = YES;

        /* Set up all of the tabs. */
        NSArray *tabs = @[_installView,
                          _recipeRepoView,
                          _scheduleView,
                          _notificationView,
                          _toolsView];

        for (LGBaseTabViewController *viewController in tabs) {
            NSTabViewItem *tabItem = [[NSTabViewItem alloc] init];
            tabItem.identifier = NSStringFromClass([viewController class]);
            tabItem.label = viewController.tabLabel;
            tabItem.view = viewController.view;
            [_tabViews addTabViewItem:tabItem];
        }

        /* Make any modifications needed for specific tools*/

        /* The Cancel button is part of the progress panel
         * but the _scheduleView should controll it. */
        _scheduleView.cancelButton = _cancelAutoPkgRunButton;
        _toolsView.modalWindow = self.window;
    }
}

#pragma mark - Tab View Delegate
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    if (![LGToolManager requiredItemsInstalled]) {
        // Reset the tab view back to the install Tab.
        [tabView selectFirstTabViewItem:self];
        [LGToolManager displayRequirementsAlertOnWindow:self.window];
        return;
    }

    if ([tabViewItem.identifier isEqualToString:NSStringFromClass([LGToolsViewController class])]) {
        [_toolsView enableFolders];
    }
}


#pragma mark - LGProgressDelegate
- (void)startProgressWithMessage:(NSString *)message
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self.progressMessage setStringValue:message];
        [self.progressDetailsMessage setStringValue:@""];

        [self.progressIndicator setHidden:NO];
        [self.progressIndicator setIndeterminate:YES];
        [self.progressIndicator displayIfNeeded];
        [self.progressIndicator startAnimation:nil];
        [NSApp beginSheet:self.progressPanel modalForWindow:self.window modalDelegate:self didEndSelector:nil contextInfo:NULL];
    }];
}

- (void)stopProgress:(NSError *)error
{
    /* Stop the progress panel, and if an error was sent do a sheet modal */

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // Give the progress panel a second to got to 100%
        [self.progressIndicator setDoubleValue:100.0];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];

        [NSApp endSheet:self.progressPanel returnCode:0];
        [self.progressIndicator setIndeterminate:YES];
        [self.progressPanel orderOut:self];
        [self.cancelAutoPkgRunButton setHidden:YES];

        [self.progressDetailsMessage setStringValue:@""];
        [self.progressMessage setStringValue:@"Starting..."];
        [self.progressIndicator setDoubleValue:0.0];

        if (error) {
            SEL selector = nil;
            NSString *suggestion = error.localizedRecoverySuggestion ?: @"";
            NSString *truncatedString = [suggestion truncateToNumberOfLines:25];

            if (truncatedString && ![truncatedString isEqualTo:suggestion]) {
                truncatedString = [NSString stringWithFormat:@"%@\nMore details have been logged to the system.log", truncatedString];
                NSLog(@"%@", error.localizedRecoverySuggestion);
            }

            NSAlert *alert = [NSAlert alertWithMessageText:error.localizedDescription defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", truncatedString ];

            // If AutoPkg exits -1 it may be misconfigured
            if (error.code == kLGErrorAutoPkgConfig) {
                [alert addButtonWithTitle:@"Try to repair settings"];
                selector = @selector(didEndWithPreferenceRepairRequest:returnCode:);
            }

            [alert beginSheetModalForWindow:self.window
                              modalDelegate:self
                             didEndSelector:selector
                                contextInfo:nil];
        }
    }];
}

- (void)updateProgress:(NSString *)message progress:(double)progress
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.progressIndicator setIndeterminate:NO];
            [self.progressDetailsMessage setStringValue:[message truncateToLength:100]];
            [self.progressIndicator setDoubleValue:progress > 5.0 ? progress:5.0 ];
    }];
}



#pragma mark - NSAlert didEndWith selectors
- (void)didEndWithPreferenceRepairRequest:(NSAlert *)alert returnCode:(NSInteger)returnCode
{
    if (returnCode == NSAlertSecondButtonReturn) {
        NSError *error;
        NSInteger neededFixing;
        BOOL rc = [LGDefaults fixRelativePathsInAutoPkgDefaults:&error neededFixing:&neededFixing];
        if (neededFixing > 0) {
            NSAlert *alert = [NSAlert new];
            alert.messageText = [NSString stringWithFormat:@"%ld problems were found in the AutoPkg preference file", neededFixing];
            alert.informativeText = rc ? @"AutoPkgr was able to repair the AutoPkg preference file. No further action is required." : @"AutoPkgr could not repair the AutoPkg preference file. If the problem persists open an issue on the AutoPkgr GitHub page.";
            [alert beginSheetModalForWindow:self.window
                              modalDelegate:self
                             didEndSelector:nil
                                contextInfo:nil];
        } else {
            DLog(@"No problems were detected in the AutoPkg preference file.");
        }
    }
}


@end
