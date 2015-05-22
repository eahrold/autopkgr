//  LGRecipeTableView.m
//  AutoPkgr
//
//  Created by Eldon on 8/14/14.
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

#import "LGTableView.h"
#import "LGRecipeOverrides.h"
#import "LGPopularRepositories.h"

@implementation LGTableView

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    _contextualMenuMouseLocal = NSMakeRect(mousePoint.x, mousePoint.y, 1, 1);
    
    NSInteger row = [self rowAtPoint:mousePoint];
    NSString *classString = NSStringFromClass([[self dataSource] class]);

    if (theEvent.type == NSLeftMouseDown || theEvent.type == NSRightMouseDown) {
        if ([classString isEqualToString:NSStringFromClass([LGRecipeController class])]) {
            return [(LGRecipeController *)[self dataSource] contextualMenuForRecipeAtRow:row];
        } else if ([classString isEqualToString:NSStringFromClass([LGPopularRepositories class])]) {
            NSString *repo = [self repoFromRow:row];
            return [LGPopularRepositories contextualMenuForRepo:repo];
        }
    }
    return nil;
}


- (NSString *)repoFromRow:(NSInteger)row
{
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"repoName"];
    NSString *repo = [[self dataSource] tableView:self objectValueForTableColumn:column row:row];
    return repo;
}

@end
