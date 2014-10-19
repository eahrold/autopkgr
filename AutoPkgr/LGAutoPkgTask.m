//
//  LGAutoPkgTask.m
//  AutoPkgr
//
//  Created by Eldon on 8/30/14.
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

#import "LGAutoPkgTask.h"
#import "LGRecipes.h"
#import "LGVersionComparator.h"

NSString *const kLGAutoPkgTaskLock = @"com.lindegroup.autopkg.task.lock";

NSString *const kLGAutoPkgRecipeKey = @"recipe";
NSString *const kLGAutoPkgRecipePathKey = @"recipe_path";
NSString *const kLGAutoPkgRepoKey = @"repo";
NSString *const kLGAutoPkgRepoPathKey = @"repo_path";

// This is a function so in the future this could be configured to
// determine autopkg path in a more robust way.
NSString *const autopkg()
{
    return @"/usr/local/bin/autopkg";
}

typedef void (^AutoPkgReplyResultsBlock)(NSArray *results, NSError *error);
typedef void (^AutoPkgReplyReportBlock)(NSDictionary *report, NSError *error);
typedef void (^AutoPkgRepoyErrorBlock)(NSError *error);

#pragma mark - AutoPkg Task (Internal Extensions)
@interface LGAutoPkgTask ()

@property (nonatomic, assign) LGAutoPkgVerb verb;
@property (strong, atomic) NSTask *task;
@property (strong, atomic) NSMutableArray *internalArgs;
@property (strong, atomic) NSMutableDictionary *internalEnvironment;

// Raw stdout/stderr strings
@property (copy, nonatomic, readwrite) NSString *standardOutString;
@property (copy, nonatomic, readwrite) NSString *standardErrString;

// Results objects
@property (copy, nonatomic) NSString *reportPlistFile;
@property (copy, nonatomic) NSDictionary *report;
@property (copy, nonatomic, readwrite) NSArray *results;
@property (strong, nonatomic) NSError *error;

// Version
@property (copy, nonatomic) NSString *version;
@property (nonatomic, assign) BOOL AUTOPKG_VERSION_0_4_0;

@property (readwrite, nonatomic, strong) NSRecursiveLock *taskLock;

// Reply blocks
@property (copy, nonatomic, readwrite) AutoPkgReplyResultsBlock replyResultsBlock;
@property (copy, nonatomic, readwrite) AutoPkgReplyReportBlock replyReportBlock;
@property (copy, nonatomic, readwrite) AutoPkgRepoyErrorBlock replyErrorBlock;

- (NSString *)taskDescription;

@end

#pragma mark - Task Manager
@implementation LGAutoPkgTaskManager

- (void)addOperation:(LGAutoPkgTask *)op
{
    [super addOperation:op];
    if (!op.progressDelegate && _progressDelegate) {
        op.progressDelegate = _progressDelegate;
    }
}

- (void)addOperationAndWait:(LGAutoPkgTask *)op
{
    [self addOperation:op];
    [op waitUntilFinished];
}

- (void)addOperations:(NSArray *)ops waitUntilFinished:(BOOL)wait
{
    NSPredicate *classPredicate = [NSPredicate predicateWithFormat:@"SELF isKindOfClass: %@", [LGAutoPkgTask class]];
    NSArray *validObjects = [ops filteredArrayUsingPredicate:classPredicate];
    for (LGAutoPkgTask *op in validObjects) {
        if (!op.progressDelegate && _progressDelegate) {
            op.progressDelegate = _progressDelegate;
        }
    }
    [super addOperations:validObjects waitUntilFinished:wait];
}

- (void)cancel
{
    NSPredicate *classPredicate = [NSPredicate predicateWithFormat:@"SELF isKindOfClass: %@", [LGAutoPkgTask class]];
    for (LGAutoPkgTask *operation in [self.operations filteredArrayUsingPredicate:classPredicate]) {
        [operation.taskLock lock];
        if (operation.task && operation.task.isRunning) {
            DLog(@"Canceling %@", operation.taskDescription);
            [operation.task terminate];
        }
        [operation.taskLock unlock];
    }
    [super cancelAllOperations];
}

#pragma mark - Convenience Instance Methods
- (void)runRecipes:(NSArray *)recipes
             reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipeListTask];
    task.replyReportBlock = reply;
    [self addOperation:task];
}

- (void)runRecipeList:(NSString *)recipeList
           updateRepo:(BOOL)updateRepo
                reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *runTask = [LGAutoPkgTask runRecipeListTask];
    runTask.replyReportBlock = reply;

    if (updateRepo) {
        LGAutoPkgTask *repoUpdate = [LGAutoPkgTask repoUpdateTask];
        [runTask addDependency:repoUpdate];
        [self addOperation:repoUpdate];
    }

    [self addOperation:runTask];
}

- (void)search:(NSString *)recipe reply:(void (^)(NSArray *results, NSError *error))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask searchTask:recipe];
    task.replyResultsBlock = reply;
    [self addOperation:task];
}

- (void)repoUpdate:(void (^)(NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask repoUpdateTask];
    task.replyErrorBlock = reply;
    [self addOperation:task];
}

@end

#pragma mark - AutoPkg Task
@implementation LGAutoPkgTask

- (NSString *)taskDescription
{
    return [NSString stringWithFormat:@"%@ %@", self.task.launchPath, [self.task.arguments componentsJoinedByString:@" "]];
}

- (void)dealloc
{
    DLog(@"Completed AutoPkg Task:\n  %@\n", [self taskDescription]);
    self.task.terminationHandler = nil;
    self.replyErrorBlock = nil;
    self.replyReportBlock = nil;
    self.replyResultsBlock = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.internalArgs = [[NSMutableArray alloc] initWithArray:@[ autopkg() ]];
        _taskLock = [[NSRecursiveLock alloc] init];
        _taskLock.name = kLGAutoPkgTaskLock;
        _taskStatusDelegate = self;
    }
    return self;
}

- (instancetype)initWithArguments:(NSArray *)arguments
{
    self = [self init];
    if (self) {
        self.arguments = arguments;
    }
    return self;
}

#pragma mark - NSOperation
- (void)main
{
    @autoreleasepool
    {
        [self launch];

        LGAutoPkgTaskResponseObject *response = [[LGAutoPkgTaskResponseObject alloc] init];
        response.results = self.results;
        response.report = self.report;
        response.error = self.error;

        [(NSObject *)_taskStatusDelegate performSelectorOnMainThread:@selector(didCompleteOperation:) withObject:response waitUntilDone:NO];
    }
}

- (BOOL)isExecuting
{
    return [self.task isRunning] && [super isExecuting];
}

- (BOOL)isFinished
{
    return ![self.task isRunning] && [super isFinished];
}

#pragma mark - Life Cycle
- (BOOL)launch
{
    self.task = [[NSTask alloc] init];
    self.task.launchPath = @"/usr/bin/python";

    [self.task setArguments:self.internalArgs];

    // If an instance of autopkg is running,
    // and we're trying to do a run, exit
    if (_verb == kLGAutoPkgRun && [[self class] instanceIsRunning]) {
        self.error = [LGError errorWithCode:kLGErrorMultipleRunsOfAutopkg];
        return NO;
    }

    [self configureFileHandles];
    [self configureEnvironment];

    if (self.internalEnvironment) {
        self.task.environment = self.internalEnvironment;
    }

    [self.task launch];
    [self.task waitUntilExit];

    // make sure the out and error readability handlers get set to nil
    // so the filehandle will get closed
    if ([self.task.standardOutput isKindOfClass:[NSPipe class]]) {
        [self.task.standardOutput fileHandleForReading].readabilityHandler = nil;
    }

    if ([self.task.standardError isKindOfClass:[NSPipe class]]) {
        [self.task.standardError fileHandleForReading].readabilityHandler = nil;
    }

    [self.taskLock lock];
    self.error = [LGError errorWithTaskError:self.task verb:_verb];
    [self.taskLock unlock];

    return (self.task.terminationStatus == 0);
}

- (void)launchInBackground:(void (^)(NSError *))reply
{
    LGAutoPkgTaskManager *bgQueue = [LGAutoPkgTaskManager new];
    DLog(@"bgQueue: %@", bgQueue.name);
    self.replyErrorBlock = reply;
    [bgQueue addOperation:self];
}

#pragma mark - Accessors
- (void)setArguments:(NSArray *)arguments
{
    [self.taskLock lock];
    /** _arguments is the externally set values
     * _internalArguments is the mutable array that has
     *  the path to autopkg set as the first object during init
     */
    _arguments = arguments;
    BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"verboseAutoPkgRun"];
    [self.internalArgs addObjectsFromArray:arguments];

    NSString *verbString = [_arguments firstObject];
    if ([verbString isEqualToString:@"run"]) {
        _verb = kLGAutoPkgRun;
        if (self.AUTOPKG_VERSION_0_4_0) {
            [self.internalArgs addObject:self.reportPlistFile];
        }
        if (verbose) {
            [self.internalArgs addObject:@"-v"];
        }
    } else if ([verbString isEqualToString:@"search"]) {
        _verb = kLGAutoPkgSearch;
    } else if ([verbString isEqualToString:@"list-recipes"]) {
        _verb = kLGAutoPkgRecipeList;
    } else if ([verbString isEqualToString:@"make-override"]) {
        _verb = kLGAutoPkgMakeOverride;
    } else if ([verbString isEqualToString:@"repo-add"]) {
        _verb = kLGAutoPkgRepoAdd;
    } else if ([verbString isEqualToString:@"repo-delete"]) {
        _verb = kLGAutoPkgRepoDelete;
    } else if ([verbString isEqualToString:@"repo-list"]) {
        _verb = kLGAutoPkgRepoList;
    } else if ([verbString isEqualToString:@"repo-update"]) {
        _verb = kLGAutoPkgRepoUpdate;
    } else if ([verbString isEqualToString:@"version"]) {
        _verb = kLGAutoPkgVersion;
    }

    [self.taskLock unlock];
}

- (NSString *)version
{
    if (!_version) {
        _version = [[self class] version];
    }
    return _version;
}

#pragma mark - Task config helpers
- (void)configureFileHandles
{
    self.task.standardError = [NSPipe pipe];
    self.task.standardOutput = [NSPipe pipe];

    if (_verb == kLGAutoPkgRun || _verb == kLGAutoPkgRepoUpdate) {
        if (self.AUTOPKG_VERSION_0_4_0) {
            __block double count = 0.0;
            double total;
            NSPredicate *progressPredicate;

            if (_verb == kLGAutoPkgRun) {
                progressPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'Processing'"];
                total = [self recipeListCount];
            } else if (_verb == kLGAutoPkgRepoUpdate) {
                progressPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] '.git'"];
                total = [[[self class] repoList] count];
            }

            [[self.task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
                NSString *message = [[NSString alloc]initWithData:[handle availableData] encoding:NSUTF8StringEncoding];

                if ([progressPredicate evaluateWithObject:message]) {
                    NSString *fullMessage;
                    if (_verb == kLGAutoPkgRepoUpdate) {
                        fullMessage = [NSString stringWithFormat:@"Updating %@", [message lastPathComponent]];
                    } else {
                        int cntStr = (int)round(count) + 1;
                        int totStr = (int)round(total);
                        fullMessage = [[NSString stringWithFormat:@"(%d/%d) %@", cntStr, totStr, message] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                    }
                    double progress = ((count/total) * 100);

                    LGAutoPkgTaskResponseObject *response = [[LGAutoPkgTaskResponseObject alloc] init];
                    response.progressMessage = fullMessage;
                    response.progress = progress;
                    count++;

                    [(NSObject *)_taskStatusDelegate performSelectorOnMainThread:@selector(didReceiveStatusUpdate:) withObject:response waitUntilDone:NO];

                } else {
                    NSLog(@"%@",message);
                }
            }];
        }
    }
}

- (void)configureEnvironment
{
    // If the task is a network operation set proxies
    if ([self isNetworkOperation]) {

        LGDefaults *defaults = [[LGDefaults alloc] init];
        NSString *httpProxy = [defaults objectForKey:@"HTTP_PROXY"];
        NSString *httpsProxy = [defaults objectForKey:@"HTTPS_PROXY"];

        if (httpProxy) {
            [self addEnvironmentVariable:httpProxy forKey:@"HTTP_PROXY"];
            DLog(@"Using HTTP_PROXY: %@", httpProxy);
        }

        if (httpsProxy) {
            [self addEnvironmentVariable:httpsProxy forKey:@"HTTPS_PROXY"];
            DLog(@"Using HTTPS_PROXY: %@", httpsProxy);
        }
    }

    if (_verb == kLGAutoPkgRun || _verb == kLGAutoPkgRepoUpdate) {
        // To get status from autopkg set NSUnbufferedIO environment key to YES
        // Thanks to help from -- http://stackoverflow.com/questions/8251010
        [self addEnvironmentVariable:@"YES" forKey:@"NSUnbufferedIO"];
    }
}

- (void)addEnvironmentVariable:(NSString *)variable forKey:(NSString *)key
{
    if (!_internalEnvironment) {
        _internalEnvironment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    }
    [_internalEnvironment setObject:variable forKey:key];
}

#pragma mark - Output / Results
- (NSString *)standardErrString
{
    [self.taskLock lock];
    if (!_standardErrString && !self.task.isRunning) {
        NSData *data;
        if ([self.task.standardError isKindOfClass:[NSPipe class]]) {
            data = [[self.task.standardError fileHandleForReading] readDataToEndOfFile];
            if (data) {
                _standardErrString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            }
        }
    }
    [self.taskLock unlock];
    return _standardErrString;
}

- (NSString *)standardOutString
{
    [self.taskLock lock];
    if (!_standardOutString && !self.task.isRunning) {
        NSData *data;
        if ([self.task.standardOutput isKindOfClass:[NSPipe class]]) {
            data = [[self.task.standardOutput fileHandleForReading] readDataToEndOfFile];
            if (data) {
                _standardOutString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            }
        }
    }
    [self.taskLock unlock];
    return _standardOutString;
}

- (NSDictionary *)report
{
    if (_report || !_verb == kLGAutoPkgRun) {
        return _report;
    }

    if (self.AUTOPKG_VERSION_0_4_0) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *reportPlistFile = self.reportPlistFile;

        if (reportPlistFile && [fm fileExistsAtPath:self.reportPlistFile]) {
            // Create dictionary from the tmp file
            _report = [NSDictionary dictionaryWithContentsOfFile:reportPlistFile];

            // Cleanup the tmp file (unless debugging is enabled)
            if (![[LGDefaults standardUserDefaults] debug]) {
                NSError *error;
                if (![fm removeItemAtPath:reportPlistFile error:&error]) {
                    DLog(@"Error removing autopkg run report-plist: %@", error.localizedDescription);
                }
            }
        }
    } else {
        NSString *plistString = self.standardOutString;
        if (plistString && ![plistString isEqualToString:@""]) {
            // Convert string back to data for plist serialization
            NSData *plistData = [plistString dataUsingEncoding:NSUTF8StringEncoding];
            // Initialize plist format
            NSPropertyListFormat format;
            // Initialize our dict
            _report = [NSPropertyListSerialization propertyListWithData:plistData
                                                                options:NSPropertyListImmutable
                                                                 format:&format
                                                                  error:nil];
        }
    }
    return _report;
}

- (NSString *)reportPlistFile
{
    if (!_reportPlistFile) {
        NSString *reportSubfolder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
        NSFileManager *mgr = [NSFileManager defaultManager];
        BOOL isDir;
        if (![mgr fileExistsAtPath:reportSubfolder isDirectory:&isDir] || !isDir) {
            if (!isDir) {
                [mgr removeItemAtPath:reportSubfolder error:nil];
            }
            [mgr createDirectoryAtPath:reportSubfolder withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSDateFormatter *fomatter = [[NSDateFormatter alloc] init];
        [fomatter setDateFormat:@"YYYYMMddHHmmss"];
        _reportPlistFile = [reportSubfolder stringByAppendingPathComponent:[fomatter stringFromDate:[NSDate date]]];
    }
    return _reportPlistFile;
}

- (NSArray *)results
{
    if (!_results) {
        NSString *resultString = self.standardOutString;
        if (resultString) {
            if (_verb == kLGAutoPkgSearch) {
                __block NSMutableArray *searchResults;

                NSMutableCharacterSet *skippedCharacters = [NSMutableCharacterSet whitespaceCharacterSet];

                NSMutableCharacterSet *repoCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
                [repoCharacters formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];

                NSPredicate *nonRecipePredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'To add' \
                                                   or SELF BEGINSWITH '----' \
                                                   or SELF BEGINSWITH 'Name'"];

                [resultString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
                    if (![nonRecipePredicate evaluateWithObject:line ]) {
                        NSScanner *scanner = [NSScanner scannerWithString:line];
                        [scanner setCharactersToBeSkipped:skippedCharacters];

                        NSString *recipe, *repo, *path;

                        [scanner scanCharactersFromSet:repoCharacters intoString:&recipe];
                        [scanner scanCharactersFromSet:repoCharacters intoString:&repo];
                        [scanner scanCharactersFromSet:repoCharacters intoString:&path];

                        if (recipe && repo && path) {
                            if (!searchResults) {
                                searchResults = [[NSMutableArray alloc] init];
                            }
                            [searchResults addObject:@{kLGAutoPkgRecipeKey:[recipe stringByDeletingPathExtension],
                                                       kLGAutoPkgRepoKey:repo,
                                                       kLGAutoPkgRepoPathKey:path,
                                                       }];
                        }
                    }
                }];
                _results = [NSArray arrayWithArray:searchResults];
            } else if (_verb == kLGAutoPkgRepoList || _verb == kLGAutoPkgRecipeList) {
                NSArray *listResults = [resultString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                NSPredicate *noEmptyStrings = [NSPredicate predicateWithFormat:@"not (SELF == '')"];
                _results = [listResults filteredArrayUsingPredicate:noEmptyStrings];
            }
        }
    }

    return _results;
}

#pragma mark - Utility

- (BOOL)AUTOPKG_VERSION_0_4_0
{
    return [LGVersionComparator isVersion:self.version greaterThanVersion:@"0.3.9"];
}

- (BOOL)isNetworkOperation
{
    if (_verb == kLGAutoPkgRun || _verb == kLGAutoPkgSearch || _verb == kLGAutoPkgRepoAdd || _verb == kLGAutoPkgRepoUpdate) {
        return YES;
    }
    return NO;
}

- (NSInteger)recipeListCount
{
    NSInteger count = 0;
    if (_verb == kLGAutoPkgRun) {
        NSString *file = [_arguments objectAtIndex:2];
        if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
            NSString *fileContents = [NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:nil];
            count = [[fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] count];
        }
    }
    return count;
}

#pragma mark - Class Methods

#pragma mark-- Recipe Methods --
+ (void)runRecipes:(NSArray *)recipes
          progress:(void (^)(NSString *, double))progress
             reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipeListTask];
    task.progressUpdateBlock = progress;

    __weak LGAutoPkgTask *weakTask = task;
    [task launchInBackground:^(NSError *error) {
        reply(weakTask.report,error);
    }];
}

+ (void)runRecipeList:(NSString *)recipeList
             progress:(void (^)(NSString *, double))progress
                reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipeListTask];
    task.progressUpdateBlock = progress;

    __weak LGAutoPkgTask *weakTask = task;
    [task launchInBackground:^(NSError *error) {
        reply(weakTask.report,error);
    }];
}

+ (void)search:(NSString *)recipe reply:(void (^)(NSArray *results, NSError *error))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask searchTask:recipe];
    __weak LGAutoPkgTask *weakTask = task;
    [task launchInBackground:^(NSError *error) {
        NSArray *results;
        if (!error) {
            results = [weakTask results];
        }
        reply(results, error);
    }];
}

+ (void)makeOverride:(NSString *)recipe reply:(void (^)(NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"make-override", recipe ];
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (NSArray *)listRecipes
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"list-recipes" ];
    [task launch];
    id results = [task results];
    return [results isKindOfClass:[NSArray class]] ? results : nil;
}

#pragma mark-- Repo Methods
+ (void)repoAdd:(NSString *)repo reply:(void (^)(NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"repo-add", repo ];
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (void)repoRemove:(NSString *)repo reply:(void (^)(NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"repo-delete", repo ];
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (void)repoUpdate:(void (^)(NSString *, double taskProgress))progress
             reply:(void (^)(NSError *error))reply;
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-update", @"all" ]];
    progress = task.progressUpdateBlock;
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (NSArray *)repoList
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"repo-list" ];
    [task launch];
    id results = [task results];
    return [results isKindOfClass:[NSArray class]] ? results : nil;
}

+ (NSString *)version
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"version" ]];
    [task launch];
    return [task standardOutString];
}

#pragma mark-- Convenience Initializers --
+ (LGAutoPkgTask *)runRecipeTask:(NSArray *)recipes
{
    LGAutoPkgTask *task = nil;
    if (recipes.count) {
        NSMutableArray *fullRecipes = [[NSMutableArray alloc] initWithCapacity:recipes.count + 2];

        [fullRecipes addObject:@"run"];
        [fullRecipes addObjectsFromArray:recipes];
        [fullRecipes addObject:@"--report-plist"];

        task = [[LGAutoPkgTask alloc] initWithArguments:[NSArray arrayWithArray:fullRecipes]];
    }

    return task;
}

+ (LGAutoPkgTask *)runRecipeListTask
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"run", @"--recipe-list", [LGRecipes recipeList], @"--report-plist" ];
    return task;
}

+ (LGAutoPkgTask *)searchTask:(NSString *)recipe
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"search", recipe ]];
    return task;
}

+ (LGAutoPkgTask *)repoUpdateTask
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-update", @"all" ]];
    return task;
}

+ (LGAutoPkgTask *)addRepoTask:(NSString *)repo
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-add", repo ]];
    return task;
}

#pragma mark-- Other Methods --
+ (BOOL)instanceIsRunning
{
    NSTask *task = [NSTask new];

    task.launchPath = @"/bin/ps";
    task.arguments = @[ @"-e", @"-o", @"command=" ];
    task.standardOutput = [NSPipe pipe];
    task.standardError = task.standardOutput;

    [task launch];
    [task waitUntilExit];

    NSData *outputData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS %@", autopkg()];
    NSArray *runningProcs = [outputString componentsSeparatedByString:@"\n"];

    if ([[runningProcs filteredArrayUsingPredicate:predicate] count]) {
        return YES;
    }
    return NO;
}

#pragma mark - Task Status Delegate Update
- (void)didReceiveStatusUpdate:(LGAutoPkgTaskResponseObject *)object
{
    NSAssert([NSThread isMainThread], @"Not Main thread!!!");

    if (object.progressMessage) {
        if (_progressUpdateBlock) {
            _progressUpdateBlock(object.progressMessage, object.progress);
        }

        if (_progressDelegate) {
            [_progressDelegate updateProgress:object.progressMessage progress:object.progress];
        }
    }
}

- (void)didCompleteOperation:(LGAutoPkgTaskResponseObject *)object
{
    NSAssert([NSThread isMainThread], @"Not Main thread!!!");

    if (_replyResultsBlock) {
        _replyResultsBlock(object.results, object.error);
    }

    if (_replyReportBlock) {
        _replyReportBlock(object.report, object.error);
    }

    if (_replyErrorBlock) {
        _replyErrorBlock(object.error);
    }
}
@end

#pragma mark - Task Response Object
@implementation LGAutoPkgTaskResponseObject
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [self init];
    if (self) {
        self.progressMessage = [decoder decodeObjectOfClass:[NSString class]
                                                     forKey:NSStringFromSelector(@selector(progressMessage))];

        self.progress = [[decoder decodeObjectOfClass:[NSNumber class]
                                               forKey:NSStringFromSelector(@selector(progress))] doubleValue];

        self.results = [decoder decodeObjectOfClass:[NSArray class]
                                             forKey:NSStringFromSelector(@selector(results))];

        self.report = [decoder decodeObjectOfClass:[NSDictionary class]
                                            forKey:NSStringFromSelector(@selector(report))];

        self.error = [decoder decodeObjectOfClass:[NSError class]
                                           forKey:NSStringFromSelector(@selector(error))];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.progressMessage forKey:NSStringFromSelector(@selector(progressMessage))];
    [coder encodeDouble:self.progress forKey:NSStringFromSelector(@selector(progress))];
    [coder encodeObject:self.results forKey:NSStringFromSelector(@selector(results))];
    [coder encodeObject:self.report forKey:NSStringFromSelector(@selector(report))];
    [coder encodeObject:self.error forKey:NSStringFromSelector(@selector(error))];
}

@end