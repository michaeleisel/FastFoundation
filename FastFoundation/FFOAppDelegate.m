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

@end
