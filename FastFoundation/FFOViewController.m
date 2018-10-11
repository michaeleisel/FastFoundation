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
#import "FFOArray.h"
#import "FFOString.h"
#import "ConvertUTF.h"
#import "FFORapidJsonTester.h"
#import "FFOJsonTester.h"
#import "FFOJsonParser.h"
#import "FFOEnvironment.h"

@interface FFOViewController ()

@end

@implementation FFOViewController {
    UINavigationController *_navController;
    UIViewController *_childController;
}

#define BENCH(name, ...) \
({ \
    printf("%s\n", name); \
    sHasGone = NO; \
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
            sHasGone = YES; \
        } \
        endTime = CACurrentMediaTime(); \
        usleep(500000); \
    } \
    printf("%.2e per second\n", count / (endTime - startTime)); \
    sShouldStop = NO; \
})

BOOL sHasGone = NO;
BOOL sShouldStop = NO;
volatile NSInteger sResult = 0;
extern int64_t process_chars(char *str, int64_t length, void *dest);

static void FFOTestProcessChars(char *string, char *dest, NSInteger length) {
    process_chars(string, length, dest);
    for (NSInteger i = 0; i < length; i++) {
        BOOL isQuote = !!((dest[i / 8] >> (7 - i % 8)) & 1);
        if (isQuote) {
            assert(string[i] == '"');
        } else {
            assert(string[i] != '"');
        }
    }
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    // FFORunTests();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    char str[5000];
    char dest[sizeof(str) / 8] = {0};
    char idxs[sizeof(str)] = {0};
    NSInteger idxsLength = 0;
    NSInteger alignment = 16;
    NSInteger mod = (NSUInteger)str % alignment;
    char *start = mod == 0 ? str : (str + alignment - mod);
    char *end = str + sizeof(str);
    end -= (NSUInteger)end % alignment;
    for (NSInteger i = 0; i < sizeof(str); i++) {
        str[i] = i % 16 == 0 ? '"' : 'a' + rand() % 26;
    }
    FFOTestProcessChars(start, dest, end - start);
    // It's ok if end < start, that will be checked for
    BENCH("mine", ({
        process_chars(start, end - start, dest);
    }));
    BENCH("sum", (int64_t)({
        NSInteger sum = 0;
        for (NSInteger i = 0; i < sizeof(str); i++) {
            sum += str[i];
        }
        str[0] = rand() % 26 + 'a';
        sum;
    }));
    // int64_t ret = process_chars("\"s\"fas\"fa\"dfasdf", 16, dest);

    uint16_t a = 0x1234;
    char *c = (char *)&a;
    printf("%#x, %#x", c[0], c[1]);

    NSString *path = [[NSBundle mainBundle] pathForResource:@"citm_catalog" ofType:@"json"];
    NS_VALID_UNTIL_END_OF_SCOPE NSData *objcData = [[[NSFileManager defaultManager] contentsAtPath:path] mutableCopy];
    char *string1 = (char *)[objcData bytes];
    char *string2 = NULL;
    asprintf(&string2, "%s", string1);
    uint32_t length = (uint32_t)strlen(string1);
    if (FFOIsDebug()) {
        NSLog(@"running in debug, don't benchmark");
        FFOTestResults(string1, length);
        gooo(string2);
        for (NSInteger i = 0; i < MIN(sMyEventCount, sEventCount); i++) {
            if (sMyEvents[i].type != sEvents[i].type) {
                NSAssert(NO, @"");
            }
            if (sMyEvents[i].type == FFOJsonTypeString) {
                NSAssert(0 == strcmp(sMyEvents[i].result.str, sEvents[i].result.str), @"");
            } else if (sMyEvents[i].type == FFOJsonTypeNum) {
                NSAssert(sMyEvents[i].result.d == sEvents[i].result.d, @"");
            }
        }
        NSAssert(sMyEventCount == sEventCount || sMyEventCount == sEventCount + 1/*hack*/, @"");
    } else {
        NSInteger nIterations = 1e2;
        char *myStrings[nIterations];
        for (NSInteger i = 0; i < nIterations; i++) {
            asprintf(&(myStrings[i]), "%s", string1);
        }
        char *rapStrings[nIterations];
        for (NSInteger i = 0; i < nIterations; i++) {
            asprintf(&(rapStrings[i]), "%s", string1);
        }
        CFTimeInterval start = CACurrentMediaTime();
        for (NSInteger i = 0; i < nIterations; i++) {
            gooo(rapStrings[i]);
        }
        CFTimeInterval end = CACurrentMediaTime();
        printf("rap: %lf\n", (end - start));
        start = CACurrentMediaTime();
        for (NSInteger i = 0; i < nIterations; i++) {
            FFOTestResults(myStrings[i], length);
        }
        end = CACurrentMediaTime();
        printf("my: %lf\n", (end - start));
        printf("%llu, %llu\n", sMyEventCount, sEventCount);
    }
    NSLog(@"done");
    /*FFOArray *quoteIdxsPtr, *slashIdxsPtr;
    NSInteger nIterations = 1e2;
    CFTimeInterval startTime = CACurrentMediaTime();
    for (NSInteger i = 0; i < nIterations; i++) {
        FFOGatherCharIdxs(string, length, &quoteIdxsPtr, &slashIdxsPtr);
    }
    CFTimeInterval endTime = CACurrentMediaTime();
    NSLog(@"%@", @(endTime - startTime));

    startTime = CACurrentMediaTime();
    for (NSInteger i = 0; i < nIterations; i++) {
        gooo(string);
    }
    endTime = CACurrentMediaTime();
    NSLog(@"%@", @(endTime - startTime));
    NSLog(@"%llu", sTotal);*/
    /*FFOJsonEvent *events = NULL;
    uint64_t eventCount = 0;
    FFOTestResults(string, (uint32_t)length, &events, &eventCount);*/
    // FFOParseJson(string, (uint32_t)length);
    // assert(FFOSearchMemChr(string, length) == 53210);
    // assert(FFOMemChr(string, length) == 53210);
    /*NSInteger total = 0;
    NSInteger nIterations = 1e3;
    for (NSInteger i = 0; i < 1; i++) {
        CFTimeInterval start = CACurrentMediaTime();
        for (NSInteger j = 0; j < nIterations; j++) {
            NSInteger l = 0;
            if (rand() % 1) {
                l = length;
            } else {
                l = length - 1;
            }
            total += FFOSearchMemChr(string, l);
        }
        CFTimeInterval end = CACurrentMediaTime();
        printf("arm %lf, %zd\n", (end - start), total);*/

        /*start = CACurrentMediaTime();
        for (NSInteger j = 0; j < nIterations; j++) {
            total += FFOMemChr(string, length);
        }
        end = CACurrentMediaTime();
        printf("memchr %lf, %zd\n", (end - start), total);*/
    //}
}

@end
