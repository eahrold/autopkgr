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
#import "LGDefaults.h"
#import "LGEmailer.h"
#import "LGHostInfo.h"
#import "LGAutoPkgTask.h"
#import "LGInstaller.h"
#import "LGAutoPkgSchedule.h"
#import "LGProgressDelegate.h"
#import "LGDisplayStatusDelegate.h"
#import "LGPasswords.h"
#import "LGTestPort.h"
#import "LGAutoPkgRecipe.h"
#import "LGToolStatus.h"

@interface LGConfigurationWindowController () {
    LGDefaults *_defaults;
    LGAutoPkgTaskManager *_taskManager;
}

@property (weak) IBOutlet NSTabView *_tabViews;
@end

@implementation LGConfigurationWindowController

#pragma mark - init/dealloc/nib

- (instancetype)init {
    if (self = [super initWithWindowNibName:NSStringFromClass([self class])]) {
        // Initialization code here.
        _defaults = [LGDefaults standardUserDefaults];

        _recipeRepoView = [[LGRecipeReposViewController alloc] initWithProgressDelegate:_progressDelegate];
        _installView = [[LGInstallViewController alloc] initWithProgressDelegate:_progressDelegate];

        _scheduleView = [[LGScheduleViewController alloc] initWithProgressDelegate:self];
        _notificationView = [[LGNotificationsViewController alloc] initWithProgressDelegate:self];
    }
    return self;
}
- (instancetype)initWithProgressDelegate:(id<LGProgressDelegate>)progressDelegate {
    if (self = [self init]) {
        _progressDelegate = progressDelegate;
    }
    return self;
}
#pragma mark - NSWindowDelegate
- (void)windowDidLoad
{
    [super windowDidLoad];

    // Install view

    NSTabViewItem *installItem = __tabViews.tabViewItems.firstObject;
    installItem.view = _installView.view;

    // Recipe & Repos view

    NSTabViewItem *rrItem = __tabViews.tabViewItems[1];
    rrItem.view = _recipeRepoView.view;

    // Schedule view
    [__tabViews.tabViewItems[2] setView:_scheduleView.view];
    _scheduleView.cancelButton = _cancelAutoPkgRunButton;

    // Notification View
    [__tabViews.tabViewItems[3] setView:_notificationView.view];

   
    // Populate the preference values from the user defaults, if they exist
    DLog(@"Populating configuration window settings based on user defaults, if they exist.");


    // Modal Windows

    // AutoPkg settings
    _localMunkiRepo.safeStringValue = _defaults.munkiRepo;
    _autoPkgCacheDir.safeStringValue = _defaults.autoPkgCacheDir;
    _autoPkgRecipeRepoDir.safeStringValue = _defaults.autoPkgRecipeRepoDir;
    _autoPkgRecipeOverridesDir.safeStringValue = _defaults.autoPkgRecipeOverridesDir;

}

- (BOOL)windowShouldClose:(id)sender
{
    DLog(@"Close command received. Configuration window is saving and closing.");
    return YES;
}

#pragma mark - Forwarding Actions

- (IBAction)cancelAutoPkgRun:(id)sender {
    [_scheduleView cancelAutoPkgRun:nil];
}


#pragma mark - Open Folder Actions
- (IBAction)openLocalMunkiRepoFolder:(id)sender
{
    DLog(@"Opening Munki repo folder...");

    NSString *munkiRepoFolder = _defaults.munkiRepo;
    BOOL isDir;

    if ([[NSFileManager defaultManager] fileExistsAtPath:munkiRepoFolder isDirectory:&isDir] && isDir) {
        NSURL *localMunkiRepoFolderURL = [NSURL fileURLWithPath:munkiRepoFolder];
        [[NSWorkspace sharedWorkspace] openURL:localMunkiRepoFolderURL];
    } else {
        NSLog(@"%@ does not exist.", munkiRepoFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the Munki repository."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the Munki repository located in %@. Please verify that this folder exists.", kLGApplicationName, munkiRepoFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgRecipeReposFolder:(id)sender
{
    DLog(@"Opening AutoPkg RecipeRepos folder...");

    NSString *repoFolder = [_defaults autoPkgRecipeRepoDir];
    BOOL isDir;

    repoFolder = repoFolder ?: [@"~/Library/AutoPkg/RecipeRepos" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:repoFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgRecipeReposFolderURL = [NSURL fileURLWithPath:repoFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgRecipeReposFolderURL];
    } else {
        NSLog(@"%@ does not exist.", repoFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg RecipeRepos folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg RecipeRepos folder located in %@. Please verify that this folder exists.", kLGApplicationName, repoFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgCacheFolder:(id)sender
{
    DLog(@"Opening AutoPkg Cache folder...");

    NSString *cacheFolder = [_defaults autoPkgCacheDir];
    BOOL isDir;

    cacheFolder = cacheFolder ?: [@"~/Library/AutoPkg/Cache" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgCacheFolderURL = [NSURL fileURLWithPath:cacheFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgCacheFolderURL];
    } else {
        NSLog(@"%@ does not exist.", cacheFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg Cache folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg Cache folder located in %@. Please verify that this folder exists.", kLGApplicationName, cacheFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgRecipeOverridesFolder:(id)sender
{
    DLog(@"Opening AutoPkg RecipeOverrides folder...");

    NSString *overridesFolder = _defaults.autoPkgRecipeOverridesDir;
    BOOL isDir;

    overridesFolder = overridesFolder ?: [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:overridesFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgRecipeOverridesFolderURL = [NSURL fileURLWithPath:overridesFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgRecipeOverridesFolderURL];
    } else {
        NSLog(@"%@ does not exist.", overridesFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg RecipeOverrides folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg RecipeOverrides folder located in %@. Please verify that this folder exists.", kLGApplicationName, overridesFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
    }
}

#pragma mark - Choose AutoPkg Folder Actions
- (IBAction)chooseLocalMunkiRepo:(id)sender
{
    DLog(@"Showing dialog for selecting Munki repo location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for munkiRepo, else /Users/Shared
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.munkiRepo ?: @"/Users/Shared"]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"Munki repo location selected.");
                    NSString *urlPath = [url path];
                    [_localMunkiRepo setStringValue:urlPath];
                    [_openLocalMunkiRepoFolderButton setEnabled:YES];
                    _defaults.munkiRepo = urlPath;
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgReciepRepoDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg RecipeRepos location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for autoPkgRecipeRepoDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgRecipeRepoDir ?: [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"AutoPkg RecipeRepos location selected.");
                    NSString *urlPath = [url path];
                    [_autoPkgRecipeRepoDir setStringValue:urlPath];
                    [_openAutoPkgRecipeReposFolderButton setEnabled:YES];
                    _defaults.autoPkgRecipeRepoDir = urlPath;

                    // Since we changed the repo directory reload the table accordingly
                }
            }
        }
    }];
}

- (IBAction)chooseAutoPkgCacheDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg Cache location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for autoPkgCacheDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgCacheDir ?: [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"AutoPkg Cache location selected.");
                    NSString *urlPath = [url path];
                    [_autoPkgCacheDir setStringValue:urlPath];
                    [_openAutoPkgCacheFolderButton setEnabled:YES];
                    _defaults.autoPkgCacheDir = urlPath;
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgRecipeOverridesDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg RecipeOverrides location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for autoPkgRecipeOverridesDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgRecipeOverridesDir ?: [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"AutoPkg RecipeOverrides location selected.");
                    NSString *urlPath = [url path];
                    [_autoPkgRecipeOverridesDir setStringValue:urlPath];
                    [_openAutoPkgRecipeOverridesFolderButton setEnabled:YES];
                    _defaults.autoPkgRecipeOverridesDir = urlPath;
                }
            }

        }
    }];
}

#pragma mark - NSTextDelegate
//- (void)controlTextDidChange:(NSNotification *)notification {
//    id object = [notification object];
//    if ([object isEqual:_smtpUsername]) {
//        _defaults.SMTPUsername = _smtpUsername.safeStringValue;
//    }
//}

//- (void)controlTextDidEndEditing:(NSNotification *)notification
//{
//    id object = [notification object];
//
//    if ([object isEqual:_smtpServer]) {
//        _defaults.SMTPServer = [_smtpServer stringValue];
//        [self testSmtpServerPort:self];
//    } else if ([object isEqual:_smtpPort]) {
//        _defaults.SMTPPort = [_smtpPort integerValue];
//        [self testSmtpServerPort:self];
//    } else if ([object isEqual:_smtpUsername]) {
//        [self getKeychainPassword:_smtpPassword];
//    } else if ([object isEqual:_smtpFrom]) {
//        _defaults.SMTPFrom = [_smtpFrom stringValue];
//    } else if ([object isEqual:_localMunkiRepo]) {
//        // Pass nil here if string is "" so it removes the key from the defaults
//        NSString *value = [[_localMunkiRepo stringValue] isEqualToString:@""] ? nil : [_localMunkiRepo stringValue];
//        _defaults.munkiRepo = value;
//        [self enableOpenInFinderButtons];
//    } else if ([object isEqual:_autoPkgRecipeOverridesDir]) {
//        // Pass nil here if string is "" so it removes the key from the defaults
//        NSString *value = [[_autoPkgRecipeOverridesDir stringValue] isEqualToString:@""] ? nil : [_autoPkgRecipeOverridesDir stringValue];
//        _defaults.autoPkgRecipeOverridesDir = value;
//        [self enableOpenInFinderButtons];
//    } else if ([object isEqual:_autoPkgRecipeRepoDir]) {
//        // Pass nil here if string is "" so it removes the key from the defaults
//        NSString *value = [[_autoPkgRecipeRepoDir stringValue] isEqualToString:@""] ? nil : [_autoPkgRecipeRepoDir stringValue];
//        _defaults.autoPkgRecipeRepoDir = value;
//        [self enableOpenInFinderButtons];
//    } else if ([object isEqual:_autoPkgCacheDir]) {
//        // Pass nil here if string is "" so it removes the key from the defaults
//        NSString *value = [[_autoPkgCacheDir stringValue] isEqualToString:@""] ? nil : [_autoPkgCacheDir stringValue];
//        _defaults.autoPkgCacheDir = value;
//        [self enableOpenInFinderButtons];
//    } else if ([object isEqual:_smtpTo]) {
//        // We use objectValue here because objectValue returns an
//        // array of strings if the field contains a series of strings
//        _defaults.SMTPTo = [_smtpTo objectValue];
//    } else if ([object isEqual:_autoPkgRunInterval]) {
//        [_progressDelegate changeCheckForNewVersionsOfAppsAutomatically:_autoPkgRunInterval];
//    } else if ([object isEqual:_smtpPassword]) {
//        // This is now handled with an IBAction
//    }
//}

#pragma mark - NSTokenFieldDelegate


#pragma mark - Tab View Delegate
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    if (![LGToolStatus requiredItemsInstalled]) {
        // Reset the tab view back to the install Tab.
        [tabView selectFirstTabViewItem:self];
        [LGToolStatus displayRequirementsAlertOnWindow:self.window];
        return;
    }

    if ([tabViewItem.identifier isEqualTo:@"localFolders"]) {
        [self enableOpenInFinderButtons];
    }
}

- (void)enableOpenInFinderButtons
{
    // Enable "Open in Finder" buttons if directories exist
    BOOL isDir;

    // AutoPkg Recipe Repos
    NSString *recipeReposFolder = [_defaults autoPkgRecipeRepoDir];
    recipeReposFolder = recipeReposFolder ?: [@"~/Library/AutoPkg/RecipeRepos" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:recipeReposFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgRecipeReposFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgRecipeReposFolderButton setEnabled:NO];
    }

    // AutoPkg Cache
    NSString *cacheFolder = [_defaults autoPkgCacheDir];
    cacheFolder = cacheFolder ?: [@"~/Library/AutoPkg/Cache" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgCacheFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgCacheFolderButton setEnabled:NO];
    }

    // AutoPkg Overrides
    NSString *overridesFolder = [_defaults autoPkgRecipeOverridesDir];
    overridesFolder = overridesFolder ?: [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:overridesFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgRecipeOverridesFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgRecipeOverridesFolderButton setEnabled:NO];
    }

    // Munki Repo
    if ([[NSFileManager defaultManager] fileExistsAtPath:_defaults.munkiRepo isDirectory:&isDir] && isDir) {
        [_openLocalMunkiRepoFolderButton setEnabled:YES];
    } else {
        [_openLocalMunkiRepoFolderButton setEnabled:NO];
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
    // Stop the progress panel, and if and error was sent in
    // do a sheet modal
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

#pragma mark - Utility
- (NSOpenPanel *)setupChoosePanel
{
    NSOpenPanel *choosePanel = [NSOpenPanel openPanel];
    // Disable the selection of files in the dialog
    [choosePanel setCanChooseFiles:NO];

    // Enable the selection of directories in the dialog
    [choosePanel setCanChooseDirectories:YES];

    // Enable the creation of directories in the dialog
    [choosePanel setCanCreateDirectories:YES];

    // Set the prompt to "Choose" instead of "Open"
    [choosePanel setPrompt:@"Choose"];

    // Disable multiple selection
    [choosePanel setAllowsMultipleSelection:NO];

    return choosePanel;
}

@end
