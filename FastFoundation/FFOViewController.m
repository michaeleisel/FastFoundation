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
#import "strlen.h"
#import "cpy_strlen.h"

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
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0); \
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

__used static void pl(long long ll) {
    for (NSInteger i = 0; i < 64; i++) {
        printf("%lld", (ll >> (63 - i)) & 1);
    }
    printf("\n");
}

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

OS_NOINLINE static size_t naive_strlen(const char *str) {
    const char *origStr = str;
    while (*str != '\0') {
        str++;
    }
    return str - origStr;
}

- (void)computeAverage:(CFTimeInterval *)average stdDev:(CFTimeInterval *)stdDev forArray:(CFTimeInterval *)array size:(NSInteger)size
{
    CFTimeInterval sum = 0;
    NSInteger skip = 1; /*skip first*/
    for (NSInteger i = skip; i < size; i++) {
        CFTimeInterval time = array[i];
        sum += time;
    }
    *average = sum / (size - skip);
    *stdDev = 0;
    for (NSInteger i = skip; i < size; i++) {
        CFTimeInterval time = array[i];
        *stdDev += (time - *average) * (time - *average);
    }
    *stdDev = sqrt(*stdDev);
}

- (void)viewDidLoad
{
	[super viewDidLoad];

    srand(0);
    NSInteger benchRuns = 10;
    NSInteger count = 15;
    NSInteger size = 100;
    NSInteger alignOffset = 0;
    CFTimeInterval appleRuns[benchRuns];
    CFTimeInterval ffoRuns[benchRuns];
    char *strs[count];
    for (NSInteger i = 0; i < count; i++) {
        strs[i] = malloc(size);
        for (NSInteger j = 0; j < size - 1; j++) {
            strs[i][j] = 'a' + (rand() % 26);
        }
        strs[i][size - 1] = '\0';

        // printf("%zd\n", ffo_strlen(strs[i] + alignOffset));
        assert(ffo_strlen(strs[i] + alignOffset) == size - alignOffset - 1);
    }

    NSInteger nIter = 1e6;

    for (NSInteger z = 0; z < benchRuns; z++) {
        ({
            CFTimeInterval start = CACurrentMediaTime();
            int sum = 0;
            for (NSInteger i = 0; i < nIter; i++) {
                for (NSInteger j = 0; j < count; j++) {
                    char *str = strs[j];
                    sum += strlen(str + alignOffset);
                }
            }
            CFTimeInterval duration = CACurrentMediaTime() - start;
            printf("apple: %lf\n", duration);
            appleRuns[z] = duration;
            if (rand() % INT_MAX == 0) printf("%d\n", sum);
        });

        /*({
            CFTimeInterval start = CACurrentMediaTime();
            int sum = 0;
            for (NSInteger i = 0; i < nIter; i++) {
                for (NSInteger j = 0; j < count; j++) {
                    sum += naive_strlen(strs[j]);
                }
            }
            CFTimeInterval end = CACurrentMediaTime();
            printf("naive: %lf\n", (end - start));
            if (rand() % INT_MAX == 0) printf("%d\n", sum);
        });*/

        /*({
            CFTimeInterval start = CACurrentMediaTime();
            int sum = 0;
            for (NSInteger i = 0; i < nIter; i++) {
                for (NSInteger j = 0; j < count; j++) {
                    sum += cpy_strlen(strs[j]);
                }
            }
            CFTimeInterval end = CACurrentMediaTime();
            printf("cpy:   %lf\n", (end - start));
            if (rand() % INT_MAX == 0) printf("%d\n", sum);
        });*/

        ({
            CFTimeInterval start = CACurrentMediaTime();
            int sum = 0;
            for (NSInteger i = 0; i < nIter; i++) {
                for (NSInteger j = 0; j < count; j++) {
                    char *str = strs[j];
                    sum += ffo_strlen(str + alignOffset);
                }
            }
            CFTimeInterval duration = CACurrentMediaTime() - start;
            printf("ffo:   %lf\n", duration);
            ffoRuns[z] = duration;
            if (rand() % INT_MAX == 0) printf("%d\n", sum);
        });
        printf("\n");
    }

    CFTimeInterval appleAverage = 0;
    CFTimeInterval appleStdDev = 0;
    [self computeAverage:&appleAverage stdDev:&appleStdDev forArray:appleRuns size:benchRuns];

    CFTimeInterval ffoAverage = 0;
    CFTimeInterval ffoStdDev = 0;
    [self computeAverage:&ffoAverage stdDev:&ffoStdDev forArray:ffoRuns size:benchRuns];

    NSLog(@"ffo: %lf±%lf, apple: %lf±%lf", ffoAverage, ffoStdDev, appleAverage, appleStdDev);

    NSLog(@"%@", @(sResult));
    return;

    NSString *path = [[NSBundle mainBundle] pathForResource:@"citm_catalog" ofType:@"json"];
    NSString *objcStr = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    const char *cStrOrig = [objcStr UTF8String];
    char *str = NULL;
    NSInteger alignment = 32;
    NSInteger length = strlen(cStrOrig);
    assert(length % alignment == 0);
    posix_memalign((void **)(&str), alignment, length);
    memcpy(str, cStrOrig, length);

    // [self _testProcessCharsWithLength:length];
    if (FFOIsDebug()) {
        NSLog(@"running in debug, don't benchmark");
        char *rapidStr = NULL;
        asprintf(&rapidStr, "%s", str);
        FFOTestResults(str, (uint32_t)length);
        gooo(rapidStr);
        for (NSInteger i = 0; i < MIN(sMyEventCount, sEventCount); i++) {
            FFOJsonEvent myEvent = sMyEvents[i];
            FFOJsonEvent event = sEvents[i];
            if (myEvent.type != event.type) {
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
        printf("rap: %lfsec\n", end - start);
        start = CACurrentMediaTime();
        for (NSInteger i = 0; i < nIterations; i++) {
            FFOTestResults(myStrings[i], (int32_t)length);
        }
        end = CACurrentMediaTime();
        printf("my: %lf\n", end - start);
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
