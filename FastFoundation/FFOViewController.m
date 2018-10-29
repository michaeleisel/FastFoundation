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
#import <sys/utsname.h>

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

extern double dyldVersionNumber;

void je_printEnvironment(void);
extern malloc_zone_t *je_orig_default_zone;

static malloc_zone_t otherZone;

static void FFOTest() __attribute__ ((optnone))
{
    // none of this stuff should cause a crash or do anything weird
    malloc_zone_t *zone = malloc_default_zone();
    char *ptr = NULL;

    free(NULL);

    malloc_zone_t newZone = {0};
    memcpy(&newZone, zone, sizeof(malloc_zone_t));
    malloc_zone_register(&newZone);
    ptr = malloc_zone_malloc(&newZone, 20);
    malloc_zone_free(&newZone, ptr);
    malloc_zone_unregister(&newZone);



    memcpy(&otherZone, zone, sizeof(malloc_zone_t));
    malloc_zone_register(&otherZone);
    ptr = malloc_zone_malloc(&otherZone, 20);
    malloc_zone_free(&otherZone, ptr);
    // leave otherZone registered

    assert(0 == strcmp(malloc_get_zone_name(zone), "jemalloc_zone"));
    const char *newName = strdup("asdf");
    malloc_set_zone_name(zone, newName);
    assert(0 == strcmp(malloc_get_zone_name(zone), "asdf"));

    ptr = malloc_zone_memalign(zone, 128, 1);
    assert(malloc_size(ptr) >= 128);
    free(ptr);

    malloc_statistics_t stats;
    bzero(&stats, sizeof(stats)); // Use bzero to make sure alignment padding is zero-filled as well
    malloc_zone_statistics(zone, &stats);
    malloc_statistics_t zeroStats;
    bzero(&zeroStats, sizeof(zeroStats));
    assert(0 == memcmp(&stats, &zeroStats, sizeof(stats)));

    for (NSInteger i = 0; i < 1000; i++) {
        ptr = malloc(i);
        if (i > 0) {
            ptr[0] = 'a';
        }
        free(ptr);
    }
    for (NSInteger i = 1e5; i < 1e6; i += 1e5) {
        ptr = malloc(i);
        bzero(ptr, i);
        free(ptr);
    }
    ptr = malloc(1e8);
    bzero(ptr, 1e8);
    free(ptr);

    ptr = malloc(20);
    malloc_zone_print_ptr_info(ptr);
    free(ptr);

    ptr = malloc(20);
    malloc_zone_log(zone, ptr);
    free(ptr);
    syscall(2);

    malloc_zone_print(zone, true);
    malloc_zone_print(NULL, true);

    ptr = malloc(20);
    assert(malloc_size(ptr) == 32);
    free(ptr);

    assert(malloc_good_size(20) == 32);

    ptr = malloc(20);
    assert(zone == malloc_zone_from_ptr(ptr));
    free(ptr);

    ptr = malloc_zone_malloc(je_orig_default_zone, 20);
    ptr = realloc(ptr, 40);
    ptr[0] = 'a';
    free(ptr);

    ptr = calloc(20, 20);
    ptr[0] = 'a';
    free(ptr);

    ptr = valloc(20);
    ptr[0] = 'a';
    free(ptr);

    ptr = malloc(20);
    malloc_zone_discharge(zone, ptr);
    free(ptr);

    ptr = malloc(20);
    malloc_zone_discharge(NULL, ptr);
    free(ptr);

    assert(malloc_zone_enable_discharge_checking(zone) == false);
    malloc_zone_disable_discharge_checking(zone);

    malloc_printf("asdf");

    zone->introspect->force_lock(zone);
    zone->introspect->force_unlock(zone);

    ptr = malloc(20);
    malloc_make_purgeable(ptr);
    assert(malloc_make_nonpurgeable(ptr) == 0);

    assert(malloc_zone_pressure_relief(zone, 20) == 0);

    assert(malloc_default_purgeable_zone() == malloc_default_zone());

    ptr = malloc(20);
    ptr[0] = 'a';
    zone->free_definite_size(zone, ptr, 20);

    ptr = malloc(20);
    assert(zone->size(zone, ptr) == 32);
    free(ptr);

    assert(malloc_zone_enable_discharge_checking(zone) == false);
    malloc_zone_enumerate_discharged_pointers(zone, ^(void *memory, void *info) {
        NSLog(@"FAIL");
    });

    ptr = realloc(NULL, 20);

    posix_memalign((void **)(&ptr), 256, 20);
    assert(malloc_size(ptr) == 256);
    free(ptr);

    void *results[30];
    malloc_zone_batch_malloc(zone, 20, results, 30);
    printf("%p\n", results[0]); // Prevent it from being optimized away
    malloc_zone_batch_free(zone, results, 30);

    assert(je_orig_default_zone != NULL && je_orig_default_zone != zone);
    // also test with -Wl,-bind_at_load
    assert(malloc_zone_check(zone));
    NSLog(@"tests pass");
    // force lock and unlock?
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    FFOTest();
    struct utsname u;
    int res = uname(&u);
    je_free(NULL);
    // je_zone_register();
    void *v = malloc(1);
    malloc_zone_t *jeZone = malloc_default_zone();
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
        NSInteger bufferLength = 16;
        char buffer[bufferLength];
        for (NSInteger i = 0; i < bufferLength - 1; i++) {
            buffer[i] = 'a' + arc4random_uniform(26);
        }
        buffer[bufferLength - 1] = '\0';
        NSInteger nIterations = 1e4;
        for (NSInteger z = 0; z < 3; z++) {
            ({
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
