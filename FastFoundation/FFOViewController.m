//
//  ViewController.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "FFOViewController.h"
#import "NSString+FFOMethods.h"

@interface FFOViewController ()

@end

@implementation FFOViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	[self runTests];
	char *const chars = "1234567890abcdefghij";
	unichar *unichars = malloc(sizeof(unichar) * strlen(chars));
	for (NSInteger i = 0; i < strlen(chars); i++) {
		unichars[i] = chars[i];
	}
	NSArray <NSArray<id>*> *pairs =
    @[
	@[@"ffo", ^{
		//[@"assdsd" ffo_componentsSeparatedByString:@"s"];
	}],
	@[@"apple", ^{
		//[@"assdsd" componentsSeparatedByString:@"s"];
	}]];
	for (NSArray <id>*pair in pairs) {
		NSLog(@"%@", pair[0]);
		[self benchmarkBlock:pair[1]];
	}
}

- (void)benchmarkBlock:(dispatch_block_t)block
{
	CFTimeInterval startTime, endTime;
	@autoreleasepool {
    	startTime = CACurrentMediaTime();
    	for (NSInteger i = 0; i < 1e6; i++) {
			block();
    	}
    	endTime = CACurrentMediaTime();
	}
	NSLog(@"%@", @(endTime - startTime));
}

- (void)runTests
{
	for (NSString *string in @[@"asdfasdf", @"AAAsafdAB", @"", @"AB"]) {
		NSString *appleString = [string lowercaseString];
		NSString *FFOString = [string ffo_lowercaseString];
		NSAssert([appleString isEqual:FFOString], @"");
	}

	for (NSArray <NSString *>*pair in @[@[@"assdsd", @"s"]]) {//, @[@"", @"s"]]) {
		NSArray <NSString *>*appleArray = [pair[0] componentsSeparatedByString:pair[1]];
		NSArray <NSString *>*FFOArray = [pair[0] ffo_componentsSeparatedByString:pair[1]];
		NSAssert([appleArray isEqual:FFOArray], @"");
	}
}

@end
