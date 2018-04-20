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
        usleep(500000); \
    } \
    printf("%.2e per second\n", count / (endTime - startTime)); \
})

- (void)pushController
{
    _childController = [[UIViewController alloc] init];
    _childController.view.backgroundColor = [UIColor greenColor];
    [_navController pushViewController:_childController animated:YES];
}

static CFAllocatorRef sRustDeallocator;

static NSString * FFOComponentsJoinedByString(NSArray<NSString *>*strings, NSString *joiner) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFAllocatorContext context = {0};
        context.deallocate = FFORustDeallocate;
        sRustDeallocator = CFAllocatorCreate(NULL, &context);
    });
    NSInteger length = strings.count;
    // CFArrayGetValues((CFArrayRef) strings, CFRangeMake(0, length), values);
    // [strings getObjects:values];
    const char *pointers[length];
    NSInteger i = 0;
    for (NSString *string in strings) {
        CFStringRef cfString = (__bridge CFStringRef)string;
        pointers[i] = CFStringGetCStringPtr(cfString, kCFStringEncodingUTF8);
        if (pointers[i] == NULL) {
            assert(NO && "fail");
            return [strings componentsJoinedByString:joiner];
        }
        i++;
    }
    const char *cJoiner = [joiner UTF8String];
    const char *result = FFOComponentsJoinedByString_Rust(pointers, length, cJoiner);
    // return CFAutorelease(CFStringCreateWithCString(kCFAllocatorDefault, result, kCFStringEncodingUTF8));
    return CFAutorelease(CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, result, kCFStringEncodingUTF8, sRustDeallocator));
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	[self runTests];
    const char *str = "the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\the quick brown fox jumped over the lazy dog\nnnnnnnnnnnthe quick brown fox jumped over the lazy dog\n";
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    NSString *longString = @"the QUICK brown FOX jumped OVER the LAZY dog";
    NSString *shortString = @", ";
    NSString *lowercaseString = @"";
    NSArray *items = @[@"the", @"quick", @"super duper long string", @"jumped", @"over", @"the"];
    for (NSInteger zz = 0; zz < 3; zz++) {
        BENCH("rust", ({
            FFOComponentsJoinedByString(items, shortString);
        }));
        BENCH("c", ({
            [items ffo_componentsJoinedByString:shortString];
        }));
        /*BENCH("objc", ({
            [items componentsJoinedByString:shortString];
        }));*/
    }
    NSLog(@"%@", @(sResult));
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
