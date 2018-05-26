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

- (void)viewDidLoad
{
	[super viewDidLoad];
    FFORunTests();

    NSString *path = [[NSBundle mainBundle] pathForResource:@"citm_catalog" ofType:@"json"];
    NS_VALID_UNTIL_END_OF_SCOPE NSData *objcData = [[[NSFileManager defaultManager] contentsAtPath:path] mutableCopy];
    char *goodString = (char *)[objcData bytes];
    uint32_t length = (uint32_t)strlen(goodString);
    char *myString = malloc(length + 1);
    char *rapString = malloc(length + 1);
    myString[length] = rapString[length] = '\0';
    if (FFOIsDebug()) {
        NSLog(@"running in debug, don't benchmark");
        memcpy(myString, goodString, length);
        memcpy(rapString, goodString, length);
        FFOTestResults(myString, length);
        gooo(rapString);
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
        NSInteger nIterations = 1e3;
        char *myStrings[nIterations];
        ({
            //for (NSInteger i = 0; i < nIterations; i++) {
            //asprintf(&(myStrings[i]), "%s", string1);
            //}
            CFTimeInterval start = CACurrentMediaTime();
            for (NSInteger i = 0; i < nIterations; i++) {
                memcpy(rapString, goodString, length);
                gooo(rapString);
            }
            CFTimeInterval end = CACurrentMediaTime();
            printf("rap: %lf\n", (end - start));
        });
        ({
            CFTimeInterval start = CACurrentMediaTime();
            for (NSInteger i = 0; i < nIterations; i++) {
                memcpy(myString, goodString, length);
                FFOTestResults(myString, length);
            }
            CFTimeInterval end = CACurrentMediaTime();
            printf("my: %lf\n", (end - start));
        });
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
