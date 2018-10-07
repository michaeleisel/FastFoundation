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
#import <malloc/malloc.h>
#import <execinfo.h>

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

/* returns the size of a block or 0 if not in this zone; must be fast, especially for negative answers */
size_t FFOZoneSize(struct _malloc_zone_t *zone, const void *ptr) {
    return je_sallocx(ptr, 0);
}

void *FFOZoneMalloc(struct _malloc_zone_t *zone, size_t size) {
    return je_malloc(size);
}

/* same as malloc, but block returned is set to zero */
void *FFOZoneCalloc(struct _malloc_zone_t *zone, size_t num_items, size_t size) {
    return je_calloc(num_items, size);
}

static inline NSInteger FFORound(double d) {
    return (NSInteger)(d + 0.5);
}

void *FFOZoneValloc(struct _malloc_zone_t *zone, size_t size) {
    void *memPtr = NULL;
    je_posix_memalign(&memPtr, FFORound(log2(getpagesize())), size);
    return memPtr;
}

void FFOZoneFree(struct _malloc_zone_t *zone, void *ptr) {
    je_free(ptr);
}

void *FFOZoneRealloc(struct _malloc_zone_t *zone, void *ptr, size_t size) {
    return je_realloc(ptr, size);
}

/*void FFOZoneDestroy(struct _malloc_zone_t *zone) {
    // no-op
}*/

+ (void)load
{
    printf("loaded\n");
}

void FFORunTests() {
}

void FFOInitialSetup() {
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    FFOInitialSetup();
    FFORunTests();

    printf("zz %d\n\n\n", getpagesize());
    /*malloc_zone_t *zone = malloc_default_zone();
    // We want to prevent the original free getting called with memory that was not malloc'd by us
    zone->free = FFOZoneFree;
    __sync_synchronize();
    zone->malloc = FFOZoneMalloc;
    zone->calloc = FFOZoneCalloc;
    zone->valloc = FFOZoneValloc;
    zone->size = FFOZoneSize;*/
    char *asdf = malloc(20);
    char *asdf2 = je_malloc(20);
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
            CFTimeInterval start = CACurrentMediaTime();
            ({
                @autoreleasepool {
                    for (NSInteger i = 0; i < nIterations; i++) {
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
