//
//  AppDelegate.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "FFOAppDelegate.h"
#import "FFOViewController.h"

@interface FFOAppDelegate ()

@end

@implementation FFOAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	_window = [[UIWindow alloc] init];
	_window.rootViewController = [[FFOViewController alloc] init];
	[_window makeKeyAndVisible];
	return YES;
}

static UIBackgroundTaskIdentifier taskId = 0;

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    taskId = [application beginBackgroundTaskWithName:@"asdf" expirationHandler:^{
        [application endBackgroundTask:taskId];
        taskId = UIBackgroundTaskInvalid;
    }];
    int64_t delayInSeconds = 10.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [application endBackgroundTask:taskId];
        taskId = UIBackgroundTaskInvalid;
    });
}

@end
