//
//  LGRecipeReposViewController.m
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGRecipeReposViewController.h"
#import "LGAutoPkgTask.h"
#import "LGRecipeController.h"
#import "LGPopularRepositories.h"

@interface LGRecipeReposViewController ()

@end

@implementation LGRecipeReposViewController

- (instancetype)init {
    return (self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil]);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib {
    NSLog(@"waking up.");
    _popRepoTableViewHandler.progressDelegate = self.progressDelegate;
}

- (NSString *)tabLabel {
    return @"Repos & Recipes";
}

- (IBAction)addAutoPkgRepoURL:(id)sender
{
    NSString *repo = [_repoURLToAdd stringValue];
    [self.progressDelegate startProgressWithMessage:[NSString stringWithFormat:@"Adding %@", repo]];

    [LGAutoPkgTask repoAdd:repo reply:^(NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.progressDelegate stopProgress:error];
        }];
    }];
    [_repoURLToAdd setStringValue:@""];
}

@end
