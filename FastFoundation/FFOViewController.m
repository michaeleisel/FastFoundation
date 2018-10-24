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
#import <mach-o/dyld.h>
#import "FFOEnabler.h"

@interface FFOViewController ()

@end

@implementation FFOViewController {
    UINavigationController *_navController;
    UIViewController *_childController;
}

void je_zone_register(void);

/*__attribute__((constructor)) void FFOStart() {
    je_zone_register();
}*/

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

static inline NSInteger FFORound(double d) {
    return (NSInteger)(d + 0.5);
}

/*size_t FFOZoneSize(struct _malloc_zone_t *zone, const void *ptr) {
    return je_sallocx(ptr, 0);
}

void *FFOZoneMalloc(struct _malloc_zone_t *zone, size_t size) {
    return je_malloc(size);
}

void *FFOZoneCalloc(struct _malloc_zone_t *zone, size_t num_items, size_t size) {
    return je_calloc(num_items, size);
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
}*/

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

extern char ***_NSGetArgv(void);

extern void je_zone_register(void);
// extern malloc_zone_t *je_get_jemalloc_zone(void);

__attribute__((constructor)) void FFORegister() {
    printf("ffo reg");
    // je_zone_register();
}

void asf(void);
extern malloc_zone_t *originalDefaultZone();
extern void wrap_free(void *p);
extern void *wrap_malloc(size_t size);

extern void *je_zone_malloc(malloc_zone_t *zone, size_t size);

- (void)viewDidLoad
{
    [super viewDidLoad];
    printf("vc\n");
    // je_zone_register();
    malloc_zone_t *jeZone = malloc_default_zone();
    // malloc_zone_t *defaultZone = originalDefaultZone();
    // printf("%p, %p\n", wrap_malloc, malloc);
    // printf("%p, %p, %p, %p\n", jeZone, jeZone->malloc, defaultZone->malloc, je_zone_malloc);
    CFAllocatorRef jeAllocator = FFOJemallocAllocator();
    jeZone->malloc(jeZone, 2);
    FFOInitialSetup();
    FFORunTests();
    NSInteger sum = 0;
    if (NO && FFOIsDebug()) {
        NSLog(@"running in debug, don't benchmark");
    } else {
        NSInteger bufferLength = 50;
        char buffer[bufferLength];
        for (NSInteger i = 0; i < bufferLength - 1; i++) {
            buffer[i] = 'a' + arc4random_uniform(26);
        }
        buffer[bufferLength - 1] = '\0';
        NSInteger nIterations = 3e6;
        for (NSInteger z = 0; z < 3; z++) {
            ({
                NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
                formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
                // NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
                CFTimeInterval start = CACurrentMediaTime();
                ({
                    @autoreleasepool {
                        for (NSInteger i = 0; i < nIterations; i++) {
                            void *p = malloc(bufferLength);
                            sum += (NSInteger)p;
                            free(p);
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
                        for (NSInteger i = 0; i < nIterations; i++) {
                            void *p = je_malloc(bufferLength);
                            sum += (NSInteger)p;
                            je_free(p);
                        }
                    }
                });
                CFTimeInterval end = CACurrentMediaTime();
                printf("my: %lf\n", (end - start));
            });
        }
    }
    // if ((rand() & 0) == 1) {
        NSLog(@"%@", @(sum));
    // }
    NSLog(@"done");
}

@end
