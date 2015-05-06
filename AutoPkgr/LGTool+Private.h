//
//  LGTool_LGTool_Private.h
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold
//

#import "LGTool.h"
#import "LGGitHubJSONLoader.h"

typedef NS_ENUM(NSInteger, LGToolTypeFlags) {
    /**
     *  Unknown Tool Type.
     */
    kLGToolTypeUnspecified = 0,
    /**
     *  Add this as a flag if the tool is a shared processor. If this is specified make sure to include the default repo property in the subclass.
     */
    kLGToolTypeAutoPkgSharedProcessor = 1 << 0,
    /**
     *  Flag to declare that the tool requires a package installation.
     */
    kLGToolTypeInstalledPackage = 1 << 1,
};

@interface LGTool () <LGProgressDelegate>

#pragma mark - Class Methods to override
/**
 *  LGTool type
 */
+ (LGToolTypeFlags)typeFlags;

/**
 *  Path to the main executable file for the tool
 *  @note this is checked for executable status
 */
+ (NSString *)binary;

/**
 *  The GitHub API address for the repo release. This is only necissary for tools with the packagedInstaller flags set This is typically similar to this https://api.github.com/repos/myrepo/releases
 */
+ (NSString *)gitHubURL;

/**
 *  Default repository if the tool is an autopkg shared processor.
 */
+ (NSString *)defaultRepository;

/**
 *  Components of the tool that indicate the tool is successful installed.
 *  @note This is only required when the tool has the SharedProcessor flag set. 
 *  @note it is unnecessary to list every item of the installer. If you have a tool that installs components in separate file system locations you should list one from each. For example JSSImporter.py exists in /Library/AutoPkg/autopkglib, but requires the python-jss library in /Library/Python/2.7/site-packages/python_jss-0.5.9-py2.7.egg/jss so each should be checked to determine if successfully installed
 */
+ (NSArray *)components;

/**
 *  The package identifier for the tool. Primarily used to determine items during uninstall:
 */
+ (NSString *)packageIdentifier;


#pragma mark - Instance methods to override

/**
 *  GitHubInfo object
 */
@property (strong, nonatomic) LGGitHubReleaseInfo *gitHubInfo;

/**
 *  An optionally dedicated download URL location. By default this is the browser_download_url of the first asset of the first array retrieved from the gitHubURL
 */
@property (copy, nonatomic, readonly) NSString *downloadURL;

/**
 *  By default this looks for the version in the receipt for an installed package with the name specified in packageIdentifier. Override this to customize the technique.
 *  @note you should not call this directly externally, and is used to initialize LGToolInfo objects without the need for subclassing that too. To access this information externally use the tool.info property.
 */
@property (copy, nonatomic, readwrite) NSString *installedVersion;

/**
 *  By default this is obtained from the GitHub repo. Override this to provide alternate ways to determine remote version.
 *  @note you should not call this directly externally, and is used to initialize LGToolInfo objects without the need for subclassing that too. To access this information externally use the tool.info property.
 */
@property (copy, nonatomic, readwrite) NSString *remoteVersion;

/**
 *  Any custom install actions that need to be taken.
 */
- (void)customInstallActions;

/**
 *  Any custom uninstall actions that need to be taken.
 */
- (void)customUninstallActions;

/**
 *  Get a version string via NSTask
 *
 *  @param exec      executable path to access the version
 *  @param arguments arguments passed to the executable
 *
 *  @return raw output from the task.
    @note All post processing of string such as stripping newlines/whitespace must be handled separately.
 */
- (NSString *)versionTaskWithExec:(NSString *)exec arguments:(NSArray *)arguments;

/**
 *  Populate an error object for failed requirements
 *
 *  @param reason the localizedSuggestion for the error
 *
 *  @return Populated NSError object
 */
- (NSError *)requirementsError:(NSString *)reason;
@end