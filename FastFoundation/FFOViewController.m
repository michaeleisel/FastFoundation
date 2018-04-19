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
#import "NSArrayFFOMethods.h"
#import "rust_bindings.h"

@interface FFOViewController ()

@end

@implementation FFOViewController {
    UINavigationController *_navController;
    UIViewController *_childController;
}

volatile static BOOL sShouldStop = NO;
static NSInteger zz = 0;
static int sResult = 0;
static char str[10000];
static NSInteger totalz = 0;

#define BENCH(name, ...) \
({ \
    printf("%s\n", name); \
    sShouldStop = NO; \
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), queue, ^(void){ \
        sShouldStop = YES; \
    }); \
    CFTimeInterval startTime, endTime; \
    NSInteger count = 0; \
    @autoreleasepool { \
        startTime = CACurrentMediaTime(); \
        while (!sShouldStop) { \
            sResult += (int)__VA_ARGS__; \
            count++; \
        } \
        endTime = CACurrentMediaTime(); \
    } \
    printf("%.1e per second\n", count / (endTime - startTime)); \
})

- (void)pushController
{
    _childController = [[UIViewController alloc] init];
    _childController.view.backgroundColor = [UIColor greenColor];
    [_navController pushViewController:_childController animated:YES];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	// [self runTests];
    //const char *str = "the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\nnnnnnnnnnnthe quick brown fox jumped over the lazy dog\n";
    printz();
    UIViewController *rootController = [[UIViewController alloc] init];
    rootController.view.backgroundColor = [UIColor purpleColor];
    UIButton *button = [[UIButton alloc] init];
    [button setTitle:@"go" forState:UIControlStateNormal];
    button.frame = CGRectMake(0, 0, 200, 200);
    button.backgroundColor = [UIColor redColor];
    [button addTarget:self action:@selector(pushController) forControlEvents:UIControlEventTouchUpInside];
    [rootController.view addSubview:button];

    _navController = [[UINavigationController alloc] initWithRootViewController:rootController];
    [self addChildViewController:_navController];
    [self.view addSubview:_navController.view];
    _navController.view.frame = self.view.bounds;

    /*for (NSInteger i = 0; i < sizeof(str) - 1; i++) {
        str[i] = arc4random_uniform(26) + 'a';
    }
    str[strlen(str) - 1] = '\0';
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    BENCH("strlen", ({
        strlen(str);
    }));
    BENCH("memchr", ({
        memchr(str, 0, sizeof(str));
    }));
    NSLog(@"%@", @(sResult));*/
    /*[self benchmarkBlock:^{
        memchr(str, 0, sizeof(str));
    }];*/
    // for (NSInteger j = 0; j < 200; j += 10) {
    	/*NSArray <NSArray<id>*> *pairs = @[
    	@[@"memchr", ^{
            memchr(str, 0, sizeof(str));
    	}],
    	@[@"strlen", ^{
            strlen(str);
    	}],
        @[@"for loop", ^{
            NSInteger cnt = 0;
            while (str[cnt] != '\0') {
                cnt++;
            }
            totalz += cnt;
        }]];
        // NSLog(@"%@", @(j));
        printf("%zd", totalz);
        for (NSInteger i = 0; i < 1; i++) {
        	for (NSArray <id>*pair in pairs) {
        		NSLog(@"%@", pair[0]);
        		[self benchmarkBlock:pair[1]];
        	}
        }*/
    // }
}

- (void)benchmarkBlock:(dispatch_block_t)block
{
    sShouldStop = NO;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), queue, ^(void){
        sShouldStop = YES;
    });
    CFTimeInterval startTime, endTime;
    NSInteger count = 0;
	@autoreleasepool {
        startTime = CACurrentMediaTime();
        while (!sShouldStop) {
			block();
            count++;
    	}
        endTime = CACurrentMediaTime();
	}
	NSLog(@"%.1e per second", count / (endTime - startTime));
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

    ({
    	NSString *longString = @"the QUICK brown FOX jumped OVER the LAZY dog";
    	NSString *shortString = @", ";
    	NSString *lowercaseString = @"";
        NSArray *items = @[@"the", @"quick", @"super duper long string", @"jumped", @"over", @"the"];
        for (NSString *string in @[longString, shortString, lowercaseString]) {
            NSString *ffoArray = [items ffo_componentsJoinedByString:string];
            NSString *appleArray = [items componentsJoinedByString:string];
            NSAssert([appleArray isEqual:ffoArray], @"");
        }
    });
}

@end
