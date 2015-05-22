//
//  LGBaseViewController.m
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGBaseViewController.h"

@interface LGBaseViewController ()

@end

@implementation LGBaseViewController

- (instancetype)init {
    return (self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil]);
}

-(instancetype)initWithProgressDelegate:(id<LGProgressDelegate>)progressDelegate {
    if (self = [self init]) {
        _progressDelegate = progressDelegate;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}


@end
