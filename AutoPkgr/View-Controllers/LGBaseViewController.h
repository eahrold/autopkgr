//
//  LGBaseViewController.h
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LGProgressDelegate.h"

@interface LGBaseViewController : NSViewController

- (instancetype)initWithProgressDelegate:(id<LGProgressDelegate>)progressDelegate;
@property (weak) id<LGProgressDelegate>progressDelegate;
@property (unsafe_unretained) NSWindow *modalWindow;

@end
