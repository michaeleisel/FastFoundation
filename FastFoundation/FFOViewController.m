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
        NSInteger nIterations = 3e6;
        NSInteger bufferLength = 50;
        char buffer[bufferLength];
        for (NSInteger i = 0; i < bufferLength - 1; i++) {
            buffer[i] = 'a' + arc4random_uniform(26);
        }
        buffer[bufferLength - 1] = '\0';
        ({
            NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
            // NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
            CFTimeInterval start = CACurrentMediaTime();
            ({
                @autoreleasepool {
                    NSInteger index = 0;
                    char letter = 'a';
                    for (NSInteger i = 0; i < nIterations; i++) {
                        index = (index + 1) % bufferLength;
                        letter++;
                        if (letter > 'z') {
                            letter = 'a';
                        }
                        buffer[index] = letter;
                        // char *newBuffer = CFAllocatorAllocate(kCFAllocatorDefault, bufferLength, 0);
                        // memcpy(buffer, newBuffer, 50);
                        CFBridgingRelease(CFStringCreateWithCString(kCFAllocatorDefault, buffer, kCFStringEncodingUTF8));
                    }
                }
            });
            CFTimeInterval end = CACurrentMediaTime();
            printf("apple: %lf\n", (end - start));
        });
        usleep(500000);
        ({
            FFODateFormatter *formatter = [[[FFODateFormatter alloc] init] autorelease];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
            CFTimeInterval start = CACurrentMediaTime();
            ({
                @autoreleasepool {
                    NSInteger index = 0;
                    char letter = 'a';
                    for (NSInteger i = 0; i < nIterations; i++) {
                        index = (index + 1) % bufferLength;
                        letter++;
                        if (letter > 'z') {
                            letter = 'a';
                        }
                        buffer[index] = letter;
                        // /*NSString *string = */[formatter stringFromDate:dates[i % dates.count]];
                        // NSLog(@"%@", string);
                        char *newBuffer = je_malloc(bufferLength);
                        memcpy(buffer, newBuffer, 50);
                        CFBridgingRelease(CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, newBuffer, kCFStringEncodingUTF8, FFOJemallocAllocator()));
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
