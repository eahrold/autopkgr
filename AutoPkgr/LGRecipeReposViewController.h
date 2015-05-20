//
//  LGRecipeReposViewController.h
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LGBaseViewController.h"
@class LGPopularRepositories, LGRecipeController;

@interface LGRecipeReposViewController : LGBaseViewController

@property (weak) IBOutlet NSTextField *repoURLToAdd;

// Objects
@property (strong) IBOutlet LGPopularRepositories *popRepoTableViewHandler;
@property (strong) IBOutlet LGRecipeController *recipeTableViewHandler;

- (IBAction)addAutoPkgRepoURL:(id)sender;

@end
