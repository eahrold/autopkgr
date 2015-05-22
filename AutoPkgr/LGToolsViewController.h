//
//  LGToolsViewController.h
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LGBaseViewController.h"

@interface LGToolsViewController : LGBaseViewController

@property (weak) IBOutlet NSTextField *localMunkiRepo;
@property (weak) IBOutlet NSTextField *autoPkgRecipeRepoDir;
@property (weak) IBOutlet NSTextField *autoPkgCacheDir;
@property (weak) IBOutlet NSTextField *autoPkgRecipeOverridesDir;


- (void)enableFolders;

// Buttons
@property (weak) IBOutlet NSButton *openLocalMunkiRepoFolderButton;
@property (weak) IBOutlet NSButton *openAutoPkgRecipeReposFolderButton;
@property (weak) IBOutlet NSButton *openAutoPkgCacheFolderButton;
@property (weak) IBOutlet NSButton *openAutoPkgRecipeOverridesFolderButton;

- (IBAction)openLocalMunkiRepoFolder:(id)sender;
- (IBAction)openAutoPkgRecipeReposFolder:(id)sender;
- (IBAction)openAutoPkgCacheFolder:(id)sender;
- (IBAction)openAutoPkgRecipeOverridesFolder:(id)sender;

- (IBAction)chooseLocalMunkiRepo:(id)sender;
- (IBAction)chooseAutoPkgCacheDir:(id)sender;
- (IBAction)chooseAutoPkgRecipeOverridesDir:(id)sender;

@end
