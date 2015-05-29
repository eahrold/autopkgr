// LGToolsStatus.m
//
// Copyright 2015 The Linde Group, Inc.
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

#import "LGToolStatus.h"

static NSArray *__toolClasses;

@implementation LGToolStatus
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // As needed add additional tools to this array.
        __toolClasses = @[
                          [LGGitTool class],
                          [LGAutoPkgTool class],
                          [LGJSSImporterTool class],
                          [LGMunkiTool class],
                          ];
    });

}

+ (NSArray *)allTools {
    return [self allToolsOnlyIfInstalled:NO];
}

+ (NSArray *)installedTools {
    return [self allToolsOnlyIfInstalled:YES];
}

+ (NSArray *)allToolsOnlyIfInstalled:(BOOL)onlyIfInstalled
{

    NSMutableArray *initedTools = [NSMutableArray arrayWithCapacity:__toolClasses.count];

    for (Class toolClass in __toolClasses) {
        // Using the class method check determine if the tool is installed
        // If it's do not add it to the array.
        if (!onlyIfInstalled || (onlyIfInstalled && [toolClass isInstalled])) {
            id tool = [[toolClass alloc] init];
            if (tool) {
                [initedTools addObject:tool];
            }
        }
    }
    return [initedTools copy];
}

#pragma mark - Class Methods
+ (BOOL)requiredItemsInstalled
{
    return ([LGAutoPkgTool isInstalled] &&
            [LGGitTool isInstalled]);
}

+ (void)displayRequirementsAlertOnWindow:(NSWindow *)window
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Required components not installed."
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"AutoPkgr requires both AutoPkg and Git. Please install both before proceeding."];

    [alert beginSheetModalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

@end