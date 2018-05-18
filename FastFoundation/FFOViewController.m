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
#import <arm_neon.h>
#import <arm_acle.h>

@interface FFOViewController ()

@end

@implementation FFOViewController {
    UINavigationController *_navController;
    UIViewController *_childController;
}

volatile static BOOL sShouldStop = NO;
static NSInteger zz = 0;
static int sResult = 0;
static char str[10000];
static NSInteger totalz = 0;

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

- (void)pushController
{
    _childController = [[UIViewController alloc] init];
    _childController.view.backgroundColor = [UIColor greenColor];
    [_navController pushViewController:_childController animated:YES];
}

static CFAllocatorRef sRustDeallocator;

static NSString * FFOComponentsJoinedByString(NSArray<NSString *>*strings, NSString *joiner) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFAllocatorContext context = {0};
        context.deallocate = FFORustDeallocate;
        sRustDeallocator = CFAllocatorCreate(NULL, &context);
    });
    NSInteger length = strings.count;
    // CFArrayGetValues((CFArrayRef) strings, CFRangeMake(0, length), values);
    // [strings getObjects:values];
    const char *pointers[length];
    NSInteger i = 0;
    for (NSString *string in strings) {
        CFStringRef cfString = (__bridge CFStringRef)string;
        pointers[i] = CFStringGetCStringPtr(cfString, kCFStringEncodingUTF8);
        if (pointers[i] == NULL) {
            assert(NO && "fail");
            return [strings componentsJoinedByString:joiner];
        }
        i++;
    }
    const char *cJoiner = [joiner UTF8String];
    const char *result = FFOComponentsJoinedByString_Rust(pointers, length, cJoiner);
    // return CFAutorelease(CFStringCreateWithCString(kCFAllocatorDefault, result, kCFStringEncodingUTF8));
    return CFAutorelease(CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, result, kCFStringEncodingUTF8, sRustDeallocator));
}

static BOOL sHasGone = NO;

/*static void inline FFOSearch(NSInteger *sum, const uint8_t *chars) {
    for (NSInteger i = 0; i < sizeof(uint32_t); i++) {
        if (chars[i] != 0) {
            (*sum)++;
        }
    }
}*/

__used static void printVec(uint8x16_t vec) {
    for (NSInteger i = 0; i < sizeof(uint8x16_t); i++) {
        printf("%zd, ", (NSInteger)vec[i]);
    }
    printf("\n");
}

__used static void printBinaryRep(uint64_t num) {
    for (NSInteger i = 0; i < sizeof(num) * 8; i++) {
        printf("%zd", (num >> (63 - i)) & 1);
    }
    printf("\n");
}

/*static NSInteger FFONaive(const char *string, NSInteger length) {
    NSInteger sum = 0;
    for (NSInteger i = 0; i < length; i++) {
        if (string[i] == '"') {
            sum++;
        }
    }
    return sum;
}*/

static const uint8x16_t sOneVec = {0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80};
static const uint8x16_t sAllZeroes = {0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0};

static const uint8_t sLow = 127 - '"';
static const uint8_t sHigh = 128 - '"';
static const uint8x16_t sLowVec = {sLow, sLow, sLow, sLow, sLow, sLow, sLow, sLow, sLow, sLow, sLow, sLow, sLow, sLow, sLow, sLow};
static const uint8x16_t sHighVec = {sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh, sHigh};

static const char *FFOSearch(const char *string, int c, NSInteger length) {
    uint8x16_t *vectors = (uint8x16_t *)string;
    NSInteger total = length / sizeof(uint8x16_t);
    total -= total % 4;
    uint8x16_t *end = vectors + total;
    uint8x16_t vector;
    while (vectors != end) {
        vector = *vectors;
        vectors++;
        uint8x16_t result = sOneVec & ((vmvnq_u8(vector + sLowVec)) & (vector + sHighVec));
        uint8_t max = vmaxvq_u8(result);
        if (max == 0) {
            uint64x2_t chunks = vreinterpretq_u64_u8(result);
            uint64_t chunk = vgetq_lane_u64(chunks, 0);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                return string + ((const char *)vectors - string - 16 + lead / 8);
            } else {
                chunk = vgetq_lane_u64(chunks, 1);
                uint64_t lead = __clzll(__rbitll(chunk));
                return string + ((const char *)vectors - string - 16 + 8 + lead / 8);
            }
        }
        vector = *vectors;
        vectors++;
        result = sOneVec & ((vmvnq_u8(vector + sLowVec)) & (vector + sHighVec));
        max = vmaxvq_u8(result);
        if (max == 0) {
            uint64x2_t chunks = vreinterpretq_u64_u8(result);
            uint64_t chunk = vgetq_lane_u64(chunks, 0);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                return string + ((const char *)vectors - string - 16 + lead / 8);
            } else {
                chunk = vgetq_lane_u64(chunks, 1);
                uint64_t lead = __clzll(__rbitll(chunk));
                return string + ((const char *)vectors - string - 16 + 8 + lead / 8);
            }
        }
        vector = *vectors;
        vectors++;
        result = sOneVec & ((vmvnq_u8(vector + sLowVec)) & (vector + sHighVec));
        max = vmaxvq_u8(result);
        if (max != 0) {
            uint64x2_t chunks = vreinterpretq_u64_u8(result);
            uint64_t chunk = vgetq_lane_u64(chunks, 0);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                return string + ((const char *)vectors - string - 16 + lead / 8);
            } else {
                chunk = vgetq_lane_u64(chunks, 1);
                uint64_t lead = __clzll(__rbitll(chunk));
                return string + ((const char *)vectors - string - 16 + 8 + lead / 8);
            }
        }
        vector = *vectors;
        vectors++;
        result = sOneVec & ((vmvnq_u8(vector + sLowVec)) & (vector + sHighVec));
        max = vmaxvq_u8(result);
        if (max != 0) {
            uint64x2_t chunks = vreinterpretq_u64_u8(result);
            uint64_t chunk = vgetq_lane_u64(chunks, 0);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                return string + ((const char *)vectors - string - 16 + lead / 8);
            } else {
                chunk = vgetq_lane_u64(chunks, 1);
                uint64_t lead = __clzll(__rbitll(chunk));
                return string + ((const char *)vectors - string - 16 + 8 + lead / 8);
            }
        }
    }

    return NULL;
}

static NSInteger FFOSearchMemChr(const char *string, NSInteger length) {
    NSInteger sum = -1;
    const char *ptr2 = string;
    const char *ptr = string;
    const char *end = ptr + length;
    while (ptr != NULL) {
        sum++;
        ptr = FFOSearch(ptr, '"', end - ptr);
        ptr2 = memchr(ptr2, '"', end - ptr2);
        if (ptr != ptr2) {
            printf("");
        }
        if (ptr != NULL) {
            ptr++;
        }
        if (ptr2 != NULL) {
            ptr2++;
        }
    }
    return sum;
}

static NSInteger FFOMemChr(const char *string, NSInteger length) {
    NSInteger sum = -1;
    const char *ptr = string;
    const char *end = ptr + length;
    while (ptr != NULL) {
        sum++;
        ptr = memchr(ptr, '"', end - ptr);
        if (ptr != NULL) {
            ptr++;
        }
    }
    return sum;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

    NSString *path = [[NSBundle mainBundle] pathForResource:@"citm_catalog" ofType:@"json"];
    NS_VALID_UNTIL_END_OF_SCOPE NSData *objcData = [[NSFileManager defaultManager] contentsAtPath:path];
    const char *string = (const char *)[objcData bytes];
    NSInteger length = strlen(string);
    // assert(FFOSearchMemChr(string, length) == 53210);
    // assert(FFOMemChr(string, length) == 53210);
    NSInteger total = 0;
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
        printf("arm %lf, %zd\n", (end - start), total);

        /*start = CACurrentMediaTime();
        for (NSInteger j = 0; j < nIterations; j++) {
            total += FFOMemChr(string, length);
        }
        end = CACurrentMediaTime();
        printf("memchr %lf, %zd\n", (end - start), total);*/
    }
}

- (void)benchmarkBlock:(dispatch_block_t)block
{
    sShouldStop = NO;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), queue, ^(void){
        sShouldStop = YES;
    });
    CFTimeInterval startTime, endTime;
    NSInteger count = 0;
	@autoreleasepool {
        startTime = CACurrentMediaTime();
        while (!sShouldStop) {
			block();
            count++;
    	}
        endTime = CACurrentMediaTime();
	}
	NSLog(@"%.1e per second", count / (endTime - startTime));
}

- (void)runTests
{
    for (NSArray <NSString *>*strings in @[@[@"abcd", @"a", @"foo"], @[@"the quick brown fox", @"o", @""]]) {
        NSString *appleString = [strings[0] stringByReplacingOccurrencesOfString:strings[1] withString:strings[2]];
        NSString *FFOString = [strings[0] ffo_stringByReplacingOccurrencesOfString:strings[1] withString:strings[2]];
        NSAssert([appleString isEqual:FFOString], @"");
    }

	for (NSString *string in @[@"asdfasdf", @"AAAsafdAB", @"", @"AB"]) {
		NSString *appleString = [string lowercaseString];
		NSString *FFOString = [string ffo_lowercaseString];
		NSAssert([appleString isEqual:FFOString], @"");
	}

	for (NSArray <NSString *>*pair in @[@[@"assdsd", @"s"]]) {//, @[@"", @"s"]]) {
		NSArray <NSString *>*appleArray = [pair[0] componentsSeparatedByString:pair[1]];
		NSArray <NSString *>*FFOArray = [pair[0] ffo_componentsSeparatedByString:pair[1]];
		NSAssert([appleArray isEqual:FFOArray], @"");
	}

    ({
    	NSString *longString = @"the QUICK brown FOX jumped OVER the LAZY dog";
    	NSString *shortString = @", ";
    	NSString *lowercaseString = @"";
        NSArray *items = @[@"the", @"quick", @"super duper long string", @"jumped", @"over", @"the"];
        for (NSString *string in @[longString, shortString, lowercaseString]) {
            NSString *ffoArray = [items ffo_componentsJoinedByString:string];
            NSString *appleArray = [items componentsJoinedByString:string];
            NSAssert([appleArray isEqual:ffoArray], @"");
        }
    });
}

@end
