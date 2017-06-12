//
//  ViewController.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "FFOViewController.h"
#import "NSString+FFOMethods.h"
#import "pcg_basic.h"

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
	NSString *longString = @"the QUICK brown FOX jumped OVER the LAZY dog";
	NSString *shortString = @"QUICK";
	NSString *lowercaseString = @"quick";
	for (NSInteger i = 0; i < 3; i++) {
    	for (NSString *string in @[longString, shortString, lowercaseString]) {
            	NSArray <NSArray<id>*> *pairs = @[
            	@[@"ffo", ^{
                    pcg32_boundedrand(100);
            	}],
            	@[@"apple", ^{
                    //arc4random_uniform(100);
            	}]];
            	for (NSArray <id>*pair in pairs) {
            		NSLog(@"%@", pair[0]);
            		[self benchmarkBlock:pair[1]];
            	}
		}
	}
}

- (void)benchmarkBlock:(dispatch_block_t)block
{
	CFTimeInterval startTime, endTime;
	@autoreleasepool {
    	startTime = CACurrentMediaTime();
    	for (NSInteger i = 0; i < 1e7; i++) {
			block();
    	}
    	endTime = CACurrentMediaTime();
	}
	NSLog(@"%@", @(endTime - startTime));
}

- (void)runTests
{
    for (NSArray <NSString *>*strings in @[@[@"abcd", @"a", @"foo"], @[@"the quick brown fox", @"o", @""]]) {
        NSString *appleString = [strings[0] stringByReplacingOccurrencesOfString:strings[1] withString:strings[2]];
        NSString *FFOString = [strings[0] ffo_stringByReplacingOccurrencesOfString:strings[1] withString:strings[2]];
        NSAssert([appleString isEqual:FFOString], @"");
    }

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
