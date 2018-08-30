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
#import "FFODateFormatter.h"
#import "FFOEnvironment.h"
#import "jemalloc.h"
#import "FFOJemallocAllocator.h"
#import "udat.h"

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

char *FFOConvertBack(UChar *buffer, NSInteger length) {
    char *str = je_malloc(length * sizeof(char) + 1);
    for (NSInteger i = 0; i < length; i++) {
        // NSCAssert(buffer[i] < 128, @"");
        str[i] = (char)buffer[i];
    }
    str[length] = '\0';
    return str;
}

UChar *FFOConvert(const char *str) {
    NSInteger len = strlen(str);
    UChar *uStr = malloc(len * sizeof(UChar));
    for (NSInteger i = 0; i < len; i++) {
        uStr[i] = str[i];
    }
    return uStr;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

    printf("zz %d\n\n\n", getpagesize());
    NSInteger length = 1e4;
    NSMutableArray <NSDate *>*dates = [[[NSMutableArray alloc] initWithCapacity:length] autorelease];
    for (NSInteger i = 0; i < length; i++) {
        NSTimeInterval interval = arc4random_uniform(60 * 60 * 24 * 365 * 2);
        interval += arc4random_uniform(1000) / 1000.0;
        NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-interval];
        [dates addObject:date];
    }
    if (NO && FFOIsDebug()) {
        NSLog(@"running in debug, don't benchmark");
    } else {
        NSInteger nIterations = 1e5;
        NSInteger bufferLength = 50;
        char buffer[bufferLength];
        for (NSInteger i = 0; i < bufferLength - 1; i++) {
            buffer[i] = 'a' + arc4random_uniform(26);
        }
        buffer[bufferLength - 1] = '\0';
        usleep(500000);
        ({
            NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
            // NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
            CFTimeInterval start = CACurrentMediaTime();
            ({
                @autoreleasepool {
                    int index = 0;
                    for (NSInteger i = 0; i < nIterations; i++) {
                        index = (index + 1) % (dates.count);
                        [formatter stringFromDate:dates[index]]; // autorelease?
                    }
                }
            });
            CFTimeInterval end = CACurrentMediaTime();
            printf("apple: %lf\n", (end - start));
        });
        usleep(500000);
        ({
            // FFODateFormatter *formatter = [[[FFODateFormatter alloc] init] autorelease];
            // formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
            UErrorCode code = U_ZERO_ERROR;
            UDateFormat *format = udat_open_57(UDAT_PATTERN, UDAT_PATTERN, "en_US_POSIX", FFOConvert("GMT"), -1, FFOConvert("yyyy-MM-dd'T'HH:mm:ssZZZZZ"), -1, &code);
            NSAssert(code == U_ZERO_ERROR || code == U_USING_FALLBACK_WARNING, @"");
            code = U_ZERO_ERROR;
            int32_t dateSize = 500 * sizeof(UChar);
            UChar *dateBuffer = je_malloc(dateSize);
            NSAssert(code == U_ZERO_ERROR, @"");
            CFTimeInterval start = CACurrentMediaTime();
            ({
                @autoreleasepool {
                    int index = 0;
                    for (NSInteger i = 0; i < nIterations; i++) {
                        index = (index + 1) % (dates.count);
                        double interval = dates[index].timeIntervalSince1970 * 1000;
                        int len = udat_format_57(format, interval, dateBuffer, dateSize, NULL, &code);
                        char *finalStr = FFOConvertBack(dateBuffer, len);
                        CFAutorelease(CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, finalStr, kCFStringEncodingUTF8, FFOJemallocAllocator()));
                    }
                }
            });
            CFTimeInterval end = CACurrentMediaTime();
            printf("my: %lf\n", (end - start));
        });
    }
    NSLog(@"done");
}

@end
