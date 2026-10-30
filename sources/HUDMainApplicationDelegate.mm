//
//  HUDMainApplicationDelegate.mm
//  TrollSpeed
//
//  Created by Lessica on 2024/1/24.
//

#import <objc/runtime.h>

#import "HUDMainApplicationDelegate.h"
#import "HUDMainWindow.h"
#import "HUDRootViewController.h"

#import "SBSAccessibilityWindowHostingController.h"
#import "UIWindow+Private.h"

@implementation HUDMainApplicationDelegate {
    HUDRootViewController *_rootViewController;
    SBSAccessibilityWindowHostingController *_windowHostingController;
}

- (instancetype)init
{
    if (self = [super init])
    {
        log_debug(OS_LOG_DEFAULT, "- [HUDMainApplicationDelegate init]");
    }
    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary <UIApplicationLaunchOptionsKey, id> *)launchOptions
{
    log_debug(OS_LOG_DEFAULT, "- [HUDMainApplicationDelegate application:%{public}@ didFinishLaunchingWithOptions:%{public}@]", application, launchOptions);

    _rootViewController = [[HUDRootViewController alloc] init];

    self.window = [[HUDMainWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window setRootViewController:_rootViewController];
    
    [self.window setWindowLevel:10000010.0];
    [self.window setHidden:NO];
    [self.window makeKeyAndVisible];

    _windowHostingController = [[objc_getClass("SBSAccessibilityWindowHostingController") alloc] init];

    void (^registerContext)(void) = ^{
        unsigned int contextId = [self.window _contextId];
        double windowLevel = [self.window windowLevel];
        if (contextId == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                unsigned int retryContextId = [self.window _contextId];
                if (retryContextId != 0 && self->_windowHostingController) {
                    double retryLevel = [self.window windowLevel];
                    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                    [invocation setTarget:self->_windowHostingController];
                    [invocation setSelector:NSSelectorFromString(@"registerWindowWithContextID:atLevel:")];
                    [invocation setArgument:&retryContextId atIndex:2];
                    [invocation setArgument:&retryLevel atIndex:3];
                    [invocation invoke];
                }
            });
            return;
        }

        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self->_windowHostingController];
        [invocation setSelector:NSSelectorFromString(@"registerWindowWithContextID:atLevel:")];
        [invocation setArgument:&contextId atIndex:2];
        [invocation setArgument:&windowLevel atIndex:3];
        [invocation invoke];
    };

    registerContext();

    return YES;
}

@end
