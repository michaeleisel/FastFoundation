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

__attribute__((constructor)) void FFORegister() {
    // je_zone_register();
}

size_t je_zone_size(malloc_zone_t *zone, const void *ptr);
void * je_zone_malloc(malloc_zone_t *zone, size_t size);
void * je_zone_calloc(malloc_zone_t *zone, size_t num, size_t size);
void * je_zone_valloc(malloc_zone_t *zone, size_t size);
void je_zone_free(malloc_zone_t *zone, void *ptr);
void * je_zone_realloc(malloc_zone_t *zone, void *ptr, size_t size);
void * je_zone_memalign(malloc_zone_t *zone, size_t alignment, size_t size);
void je_zone_free_definite_size(malloc_zone_t *zone, void *ptr, size_t size);
void je_zone_destroy(malloc_zone_t *zone);
unsigned je_zone_batch_malloc(struct _malloc_zone_t *zone, size_t size, void **results, unsigned num_requested);
void je_zone_batch_free(struct _malloc_zone_t *zone, void **to_be_freed, unsigned num_to_be_freed);
size_t je_zone_pressure_relief(struct _malloc_zone_t *zone, size_t goal);
size_t je_zone_good_size(malloc_zone_t *zone, size_t size);
kern_return_t
je_zone_enumerator(task_t task, void *data, unsigned type_mask,
                vm_address_t zone_address, memory_reader_t reader,
                vm_range_recorder_t recorder);
boolean_t je_zone_check(malloc_zone_t *zone);
void je_zone_print(malloc_zone_t *zone, boolean_t verbose);
void je_zone_log(malloc_zone_t *zone, void *address);
void je_zone_force_lock(malloc_zone_t *zone);
void je_zone_force_unlock(malloc_zone_t *zone);
void je_zone_statistics(malloc_zone_t *zone, malloc_statistics_t *stats);
boolean_t je_zone_locked(malloc_zone_t *zone);
void je_zone_reinit_lock(malloc_zone_t *zone);

/*size_t    zone_size(malloc_zone_t *zone, const void *ptr);
void    *zone_malloc(malloc_zone_t *zone, size_t size);
void    *zone_calloc(malloc_zone_t *zone, size_t num, size_t size);
void    *zone_valloc(malloc_zone_t *zone, size_t size);
void    zone_free(malloc_zone_t *zone, void *ptr);
void    *zone_realloc(malloc_zone_t *zone, void *ptr, size_t size);
void    *zone_memalign(malloc_zone_t *zone, size_t alignment,
                              size_t size);
void    zone_free_definite_size(malloc_zone_t *zone, void *ptr,
                                       size_t size);
void    zone_destroy(malloc_zone_t *zone);
unsigned    zone_batch_malloc(struct _malloc_zone_t *zone, size_t size,
                                     void **results, unsigned num_requested);
void    zone_batch_free(struct _malloc_zone_t *zone,
                               void **to_be_freed, unsigned num_to_be_freed);
size_t    zone_pressure_relief(struct _malloc_zone_t *zone, size_t goal);
size_t    zone_good_size(malloc_zone_t *zone, size_t size);
kern_return_t    zone_enumerator(task_t task, void *data, unsigned type_mask,
                                        vm_address_t zone_address, memory_reader_t reader,
                                        vm_range_recorder_t recorder);
boolean_t    zone_check(malloc_zone_t *zone);
void    zone_print(malloc_zone_t *zone, boolean_t verbose);
void    zone_log(malloc_zone_t *zone, void *address);
void    zone_force_lock(malloc_zone_t *zone);
void    zone_force_unlock(malloc_zone_t *zone);
void    zone_statistics(malloc_zone_t *zone,
                               malloc_statistics_t *stats);
static boolean_t    zone_locked(malloc_zone_t *zone);
static void    zone_reinit_lock(malloc_zone_t *zone);*/





static void FFOZoneInit(malloc_zone_t *jemalloc_zone) {
    malloc_introspection_t jemalloc_zone_introspect = {0};
    jemalloc_zone_introspect.enumerator = je_zone_enumerator;
    jemalloc_zone_introspect.good_size = je_zone_good_size;
    jemalloc_zone_introspect.check = je_zone_check;
    jemalloc_zone_introspect.print = je_zone_print;
    jemalloc_zone_introspect.log = je_zone_log;
    jemalloc_zone_introspect.force_lock = je_zone_force_lock;
    jemalloc_zone_introspect.force_unlock = je_zone_force_unlock;
    jemalloc_zone_introspect.statistics = je_zone_statistics;
    jemalloc_zone_introspect.zone_locked = je_zone_locked;
    jemalloc_zone_introspect.enable_discharge_checking = NULL;
    jemalloc_zone_introspect.disable_discharge_checking = NULL;
    jemalloc_zone_introspect.discharge = NULL;
#ifdef __BLOCKS__
    jemalloc_zone_introspect.enumerate_discharged_pointers = NULL;
#else
    jemalloc_zone_introspect.enumerate_unavailable_without_blocks = NULL;
#endif
    jemalloc_zone_introspect.reinit_lock = je_zone_reinit_lock;

    jemalloc_zone->claimed_address = NULL;
    jemalloc_zone->size = je_zone_size;
    jemalloc_zone->free = je_zone_free;
    jemalloc_zone->batch_free = je_zone_batch_free;
    jemalloc_zone->realloc = je_zone_realloc;
    jemalloc_zone->malloc = je_zone_malloc;
    jemalloc_zone->calloc = je_zone_calloc;
    jemalloc_zone->valloc = je_zone_valloc;
    jemalloc_zone->destroy = je_zone_destroy;
    // jemalloc_zone.zone_name = "jemalloc_zone";
    jemalloc_zone->batch_malloc = je_zone_batch_malloc;
    jemalloc_zone->introspect = &jemalloc_zone_introspect;
    jemalloc_zone->version = 9;
    jemalloc_zone->memalign = je_zone_memalign;
    jemalloc_zone->free_definite_size = je_zone_free_definite_size;
    jemalloc_zone->pressure_relief = je_zone_pressure_relief;
}

void set_actual_zone(malloc_zone_t *zone);

static malloc_zone_t sOldZone = {0};

- (void)viewDidLoad
{
    [super viewDidLoad];
    je_zone_register();
    malloc_zone_t *defaultZone = malloc_default_zone();
    sOldZone = *defaultZone;
    set_actual_zone(&sOldZone);
    FFOZoneInit(defaultZone);
    // malloc_zone_t *jeZone = NULL; // je_get_jemalloc_zone();
    // defaultZone->introspect->force_lock(defaultZone);
    // printf("%p\n", malloc_zone_malloc(defaultZone, 1));
    malloc_zone_t *oldDefault = malloc_default_zone();

    FFOInitialSetup();
    FFORunTests();
    NSInteger sum = 0;
    if (NO && FFOIsDebug()) {
        NSLog(@"running in debug, don't benchmark");
    } else {
        for (NSInteger z = 0; z < 3; z++) {
            NSInteger nIterations = 1e7;
            NSInteger bytes = 16;
            ({
                CFTimeInterval start = CACurrentMediaTime();
                @autoreleasepool {
                    for (NSInteger i = 0; i < nIterations; i++) {
                        void *ptr = malloc(bytes);
                        sum += (NSInteger)ptr;
                        free(ptr);
                    }
                }
                CFTimeInterval end = CACurrentMediaTime();
                printf("apple: %lf\n", (end - start));
            });
            ({
                CFTimeInterval start = CACurrentMediaTime();
                @autoreleasepool {
                    for (NSInteger i = 0; i < nIterations; i++) {
                        void *ptr = je_malloc(bytes); // je_malloc(bytes);
                        sum += (NSInteger)ptr;
                        je_free(ptr);
                    }
                }
                CFTimeInterval end = CACurrentMediaTime();
                printf("my: %lf\n", (end - start));
            });
            ({
                CFTimeInterval start = CACurrentMediaTime();
                @autoreleasepool {
                    for (NSInteger i = 0; i < nIterations; i++) {
                        void *ptr = malloc_zone_malloc(defaultZone, bytes);
                        sum += (NSInteger)ptr;
                        malloc_zone_free(defaultZone, ptr);
                    }
                }
                CFTimeInterval end = CACurrentMediaTime();
                printf("malloc_zone default: %lf\n", (end - start));
            });
            /*({
                CFTimeInterval start = CACurrentMediaTime();
                @autoreleasepool {
                    for (NSInteger i = 0; i < nIterations; i++) {
                        void *ptr = malloc_zone_malloc(jeZone, bytes);
                        sum += (NSInteger)ptr;
                        malloc_zone_free(jeZone, ptr);
                    }
                }
                CFTimeInterval end = CACurrentMediaTime();
                printf("malloc_zone je: %lf\n", (end - start));
            });*/
        }
    }
    // if ((rand() & 0) == 1) {
        NSLog(@"%@", @(sum));
    // }
    NSLog(@"done");
}

@end
