//
//  LGAutoPkgrHelper.m
//  AutoPkgr
//
//  Created by Eldon on 7/28/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGAutoPkgrHelper.h"
#import "LGAutoPkgrProtocol.h"
#import "LGConstants.h"
#import "AHLaunchCtl.h"
#import "AHKeychain.h"

#import <pwd.h>
#import <syslog.h>

static const NSTimeInterval kHelperCheckInterval = 1.0; // how often to check whether to quit

@interface LGAutoPkgrHelper () <HelperAgent, NSXPCListenerDelegate>
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (weak) NSXPCConnection *connection;
@property (nonatomic, assign) BOOL helperToolShouldQuit;
@end

@implementation LGAutoPkgrHelper

- (id)init
{
    self = [super init];
    if (self) {
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kAutoPkgrHelperToolName];
        self->_listener.delegate = self;
    }
    return self;
}

- (void)run
{
    [self.listener resume];
    while (!self.helperToolShouldQuit) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kHelperCheckInterval]];
    }
}

#pragma mark - AutoPkgr Protocol
- (void)scheduleRun:(NSInteger)interval
               user:(NSString *)user
            program:(NSString *)program
      authorization:(NSData *)authData
              reply:(void (^)(NSError *error))reply
{

    NSError *error = [LGAutoPkgrAuthorizer checkAuthorization:authData
                                                      command:_cmd];
    if (error != nil) {
        return reply(error);
    }

    [self scheduleRun:interval user:user program:program reply:reply];
}

- (void)scheduleRun:(NSInteger)interval
               user:(NSString *)user
            program:(NSString *)program
              reply:(void (^)(NSError *))reply
{
    NSError *error;
    AHLaunchJob *job = [AHLaunchJob new];
    job.Program = program;
    job.Label = kLGAutoPkgrLaunchDaemonPlist;
    job.ProgramArguments = @[ program, @"-runInBackground", @"YES", @"-asUser", user ];
    job.StartInterval = interval;
    job.SessionCreate = YES;

    [[AHLaunchCtl sharedControler] add:job toDomain:kAHGlobalLaunchDaemon error:&error];
    reply(error);
}

- (void)removeScheduleWithAuthorization:(NSData *)authData reply:(void (^)(NSError *))reply
{
    NSError *error = [LGAutoPkgrAuthorizer checkAuthorization:authData
                                                      command:_cmd];
    if (error != nil) {
        return reply(error);
    }
    [self removeScheduleWithReply:reply];
}

- (void)removeScheduleWithReply:(void (^)(NSError *))reply
{
    NSError *error;
    [[AHLaunchCtl sharedControler] remove:kLGAutoPkgrLaunchDaemonPlist fromDomain:kAHGlobalLaunchDaemon error:&error];
    reply(error);
}

#pragma mark - Update Password
- (void)addPassword:(NSString *)password forUser:(NSString *)user andAutoPkgr:(NSString *)autoPkgrLaunchPath authorization:(NSData *)authData reply:(void (^)(NSError *))reply
{
    NSError *error = [LGAutoPkgrAuthorizer checkAuthorization:authData
                                                      command:_cmd];
    if (error != nil) {
        return reply(error);
    }
    return [self addPassword:password forUser:user andAutoPkgr:autoPkgrLaunchPath reply:reply];
}

- (void)addPassword:(NSString *)password forUser:(NSString *)user andAutoPkgr:(NSString *)autoPkgrLaunchPath reply:(void (^)(NSError *))reply
{
    NSError *error;
    AHKeychain *keychain = [AHKeychain systemKeychain];
    AHKeychainItem *item = [[AHKeychainItem alloc] init];
    item.label = kApplicationName;
    item.service = kApplicationName;
    item.account = user;
    item.password = password;
    item.trustedApplications = @[ autoPkgrLaunchPath ];
    [keychain saveItem:item error:&error];

    reply(error);
}

- (void)removePassword:(NSString *)password
               forUser:(NSString *)user
         authorization:(NSData *)authData
                 reply:(void (^)(NSError *))reply
{
    NSError *error = [LGAutoPkgrAuthorizer checkAuthorization:authData
                                                      command:_cmd];
    if (error != nil) {
        return reply(error);
    }
    return [self removePassword:password forUser:user reply:reply];
}

- (void)removePassword:(NSString *)password
               forUser:(NSString *)user
                 reply:(void (^)(NSError *))reply
{
    NSError *error;
    AHKeychain *keychain = [AHKeychain systemKeychain];
    AHKeychainItem *item = [[AHKeychainItem alloc] init];
    item.label = kApplicationName;
    item.service = kApplicationName;
    item.account = user;

    [keychain deleteItem:item error:&error];
    reply(error);
}

- (void)quitHelper:(void (^)(BOOL success))reply
{
    // this will cause the run-loop to exit;
    // you should call it via NSXPCConnection
    // during the applicationShouldTerminate routine
    self.helperToolShouldQuit = YES;
    reply(YES);
}

- (void)installPackageFromPath:(NSString *)path
                 authorization:(NSData *)authData
                         reply:(void (^)(NSError *error))reply;
{
    NSError *error;

    error = [LGAutoPkgrAuthorizer checkAuthorization:authData command:_cmd];
    if (error != nil) {
        reply(error);
        return;
    }

    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/sbin/installer";
    task.arguments = @[ @"-pkg", path, @"-target", @"/" ];
    task.standardError = [NSPipe pipe];

    [task launch];
    [task waitUntilExit];
    [self errorFromTask:task error:&error];
    reply(error);
}

- (void)uninstallWithAuthorization:(NSData *)authData reply:(void (^)(NSError *))reply
{
    NSError *error;
    if (error != nil) {
        return reply(error);
    }
    return [self uninstall:reply];
}
- (void)uninstall:(void (^)(NSError *))reply
{
    NSError *error;
    [[AHLaunchCtl sharedControler] remove:kLGAutoPkgrLaunchDaemonPlist fromDomain:kAHGlobalLaunchDaemon error:&error];

    [AHLaunchCtl removeFilesForHelperWithLabel:kAutoPkgrHelperToolName error:&error];
    reply(error);
}

#pragma mark - Error Handling
- (BOOL)errorFromTask:(NSTask *)task error:(NSError *__autoreleasing *)error
{
    if (error && task.terminationStatus != 0) {
        NSString *errMsg;
        if ([task.standardError isKindOfClass:[NSPipe class]]) {
            NSData *data = [[task.standardError fileHandleForReading] readDataToEndOfFile];
            errMsg = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        } else {
            errMsg = [NSString stringWithFormat:@"There was a problem executing %@", task.launchPath];
        }

        *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:task.terminationStatus userInfo:@{ NSLocalizedDescriptionKey : errMsg }];
    }
    return (task.terminationStatus == 0);
}

//----------------------------------------
// Set up the one method of NSXPClistener
//----------------------------------------
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{

    newConnection.exportedObject = self;
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperAgent)];
    self.connection = newConnection;

    [newConnection resume];
    return YES;
}
@end
