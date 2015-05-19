//
//  LGInfoView.m
//  AutoPkgr
//
//  Created by Eldon on 5/19/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGRecipeInfoView.h"
#import "LGAutoPkgRecipe.h"

@interface LGRecipeInfoView ()
@property (strong) IBOutlet NSTextField *nameTF;
@property (strong) IBOutlet NSTextField *identifierTF;
@property (strong) IBOutlet NSTextField *descriptionTF;
@property (strong) IBOutlet NSTextField *parentRecipesTF;
@property (strong) IBOutlet NSTextField *filePathTF;
@property (strong) IBOutlet NSTextField *minimumVersionTF;
@end

@implementation LGRecipeInfoView {
    LGAutoPkgRecipe *_recipe;
}

-(instancetype)initWithRecipe:(LGAutoPkgRecipe *)recipe {
    if (self = [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle mainBundle]]){
        _recipe = recipe;

    }
    return self;
}

- (void)awakeFromNib {
    _nameTF.stringValue = _recipe.Name;
    _identifierTF.stringValue = _recipe.Identifier;
    _parentRecipesTF.stringValue = [_recipe.ParentRecipes componentsJoinedByString:@"\n"] ?: @"";
    _descriptionTF.stringValue = _recipe.Description ?: @"";
    _minimumVersionTF.stringValue = _recipe.MinimumVersion;
    _filePathTF.stringValue = [_recipe.FilePath stringByAbbreviatingWithTildeInPath];
}

-(void)viewWillAppear{
    NSLog(@"getting ready!!!!!!");
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.

}

@end
