//
//  LGEmailer.m
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

#import "LGEmailer.h"
#import "LGAutoPkgr.h"
#import "LGHostInfo.h"
#import "AHKeychain.h"

@implementation LGEmailer

- (void)sendEmailNotification:(NSString *)subject message:(NSString *)message
{
    LGDefaults *defaults = [[LGDefaults alloc] init];

    BOOL TLS = [defaults SMTPTLSEnabled];

    MCOSMTPSession *smtpSession = [[MCOSMTPSession alloc] init];
    smtpSession.hostname = defaults.SMTPServer;
    smtpSession.port = (int)defaults.SMTPPort;
    smtpSession.username = defaults.SMTPUsername;

    if (TLS) {
        NSLog(@"SSL/TLS is enabled for %@.", defaults.SMTPServer);
        // If the SMTP port is 465, use MCOConnectionTypeTLS.
        // Otherwise use MCOConnectionTypeStartTLS.
        if (smtpSession.port == 465) {
            smtpSession.connectionType = MCOConnectionTypeTLS;
        } else {
            smtpSession.connectionType = MCOConnectionTypeStartTLS;
        }
    } else {
        NSLog(@"SSL/TLS is _not_ enabled for %@.", defaults.SMTPServer);
        smtpSession.connectionType = MCOConnectionTypeClear;
    }

    // Retrieve the SMTP password from the default
    // keychain if it exists
    NSError *error = nil;

    if (defaults.SMTPUsername) {
        NSString *password = [AHKeychain getPasswordForService:kLGApplicationName account:defaults.SMTPUsername keychain:kAHKeychainSystemKeychain error:&error];

        // Only set the SMTP session password if the username exists
        if (defaults.SMTPUsername && ![defaults.SMTPUsername isEqual:@""]) {
            NSLog(@"Retrieved password from keychain for account %@.", defaults.SMTPUsername);
            smtpSession.password = password;
        }
    }

    MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];

    [[builder header] setFrom:[MCOAddress addressWithDisplayName:@"AutoPkgr Notification"
                                                         mailbox:[defaults SMTPFrom]]];

    NSMutableArray *to = [[NSMutableArray alloc] init];
    for (NSString *toAddress in [defaults SMTPTo]) {
        if (![toAddress isEqual:@""]) {
            MCOAddress *newAddress = [MCOAddress addressWithMailbox:toAddress];
            [to addObject:newAddress];
        }
    }

    [[builder header] setTo:to];
    [[builder header] setSubject:subject];
    [builder setHTMLBody:message];
    NSData *rfc822Data = [builder data];

    MCOSMTPSendOperation *sendOperation = [smtpSession sendOperationWithData:rfc822Data];

    [sendOperation start:^(NSError *error) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{kLGNotificationUserInfoSubject:subject,
                                                                                        kLGNotificationUserInfoMessage:message}];
        
        if (error) {
            NSLog(@"%@ Error sending email:%@", smtpSession.username, error);
            [userInfo setObject:error forKey:kLGNotificationUserInfoError];
        } else {
            NSLog(@"%@ Successfully sent email!", smtpSession.username);
        }
        
        [center postNotificationName:kLGNotificationEmailSent
                              object:self
                            userInfo:[NSDictionary dictionaryWithDictionary:userInfo]];
        // since this is in a operation block, set as complete so cli invocation
        // can watch and exit out of run loop
        self.complete = YES;
    }];
}

- (void)sendTestEmail
{
    // Send a test email notification when the user
    // clicks "Send Test Email"
    NSString *subject = @"Test notification from AutoPkgr";
    NSString *message = @"This is a test notification from <strong>AutoPkgr</strong>.";
    // Send the email
    [self sendEmailNotification:subject message:message];
}

@end
