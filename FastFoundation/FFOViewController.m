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
#import "vectorizer.h"

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

static const char kChars[] = {':', ',', '"', '\\', 'a', 'z'};

__used static void pb(char c) {
    for (NSInteger i = 0; i < 8; i++) {
        printf("%d", (c >> (7 - i)) & 1);
    }
    printf("\n");
}

static void FFOTestProcessChars(char *string, char *dest, NSInteger length) {
    process_chars(string, length, dest);
    for (NSInteger i = 0; i < length; i++) {
        BOOL shouldBeSpecial = !!((dest[i / 8] >> (7 - i % 8)) & 1);
        BOOL isSpecial = !!memchr(kChars, string[i], sizeof(kChars) - 2);
        assert(isSpecial == shouldBeSpecial);
    }
}

- (void)viewDidLoad
{
	[super viewDidLoad];

    NSString *path = [[NSBundle mainBundle] pathForResource:@"citm_catalog" ofType:@"json"];
    NSString *objcStr = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    const char *cStrOrig = [objcStr UTF8String];
    char *str = NULL;
    NSInteger alignment = 32;
    NSInteger length = strlen(str);
    assert(length % alignment == 0);
    posix_memalign((void **)(&str), alignment, length);
    memcpy(str, cStrOrig, length);

    [self _testProcessCharsWithLength:length];
    if (FFOIsDebug()) {
        NSLog(@"running in debug, don't benchmark");
        FFOTestResults(str, (uint32_t)length);
        gooo(str);
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
        NSInteger nIterations = 1e1;
        char *myStrings[nIterations];
        for (NSInteger i = 0; i < nIterations; i++) {
            asprintf(&(myStrings[i]), "%s", str);
        }
        char *rapStrings[nIterations];
        for (NSInteger i = 0; i < nIterations; i++) {
            asprintf(&(rapStrings[i]), "%s", str);
        }
        CFTimeInterval start = CACurrentMediaTime();
        for (NSInteger i = 0; i < nIterations; i++) {
            gooo(rapStrings[i]);
        }
        CFTimeInterval end = CACurrentMediaTime();
        printf("rap: %lf per sec\n", nIterations / (end - start));
        start = CACurrentMediaTime();
        for (NSInteger i = 0; i < nIterations; i++) {
            FFOTestResults(myStrings[i], (int32_t)length);
        }
        end = CACurrentMediaTime();
        printf("my: %lf\n", (end - start));
        printf("%llu, %llu\n", sMyEventCount, sEventCount);
    }
    NSLog(@"done");
}

- (void)_testProcessCharsWithLength:(NSInteger)length
{
    char *str = malloc(length);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    NSInteger destLength = length / 8;
    char dest[destLength];
    memset(dest, '\0', destLength);
    NSInteger alignment = 16;
    NSInteger mod = (NSUInteger)str % alignment;
    char *start = mod == 0 ? str : (str + alignment - mod);
    char *end = str + length;
    end -= (NSUInteger)end % alignment;
    // commas, quotes, slashes, colons
    for (NSInteger i = 0; i < length; i++) {
        str[i] = kChars[rand() % sizeof(kChars)];
    }
    FFOTestProcessChars(start, dest, end - start);
    // It's ok if end < start, that will be checked for
    BENCH("mine", ({
        process_chars(start, end - start, dest);
    }));
    free(str);
}

@end
