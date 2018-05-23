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
#import "FFOArray.h"

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

typedef void (*FFOStringCallback)(char *);
typedef void (*FFONumberCallback)(double);
typedef void (*FFONotificationCallback)();

typedef struct {
    FFOStringCallback stringCallback;
    FFONumberCallback numberCallback;
    FFONotificationCallback arrayStartCallback;
    FFONotificationCallback arrayEndCallback;
    FFONotificationCallback dictionaryStartCallback;
    FFONotificationCallback dictionaryEndCallback;
} FFOCallbacks;

static void FFOGotString(char *string) {
}

static void FFOGotDictionaryStart() {
}

static void FFOGotDictionaryEnd() {
}

static void FFOGotArrayStart() {
}

static void FFOGotArrayEnd() {
}

NS_ENUM(NSInteger, FFOJsonTypes) {
    FFOJsonDictionary,
    FFOJsonArray,
};

static const char *FFOGatherCharIdxs(const char *string, NSInteger length, FFOArray **quoteIdxs, FFOArray **slashIdxs);

static inline char FFOEscapeCharForChar(char origChar) {
    switch (origChar) {
        case 't':
            return '\t';
        case '"':
            return '"';
        case '\\':
            return '\\';
        case 'b':
            return '\b';
        case 'f':
            return '\f';
        case 'n':
            return '\n';
        default:
            NSCAssert(NO, @"invalid/unsupported escape char");
            return '?';
    }
}

static inline char FFOCharFromHexCode(const char *hexCode) {
    char c = 0;
    if (hexCode[0] <= '9') {
        c += (hexCode[0] - '0') * 16;
    } else {
        c += (tolower(hexCode[0]) - 'a') * 16;
    }

    if (hexCode[1] <= '9') {
        c += hexCode[1] - '0';
    } else {
        c += tolower(hexCode[1]) - 'a';
    }

    return c;
}

static inline void FFOProcessEscapedSequence(FFOArray *deletions, char *string, uint32_t slashIdx) {
    char afterSlash = string[slashIdx + 1];
    if (afterSlash == 'u' || afterSlash == 'U') {
        FFOPushToArray(deletions, 5);
        FFOPushToArray(deletions, 5 - 2);
        string[slashIdx] = FFOCharFromHexCode(string + slashIdx + 1);
        string[slashIdx + 1] = FFOCharFromHexCode(string + slashIdx + 2);
        // string[slashIdx + 1] = ;
        NSCAssert(NO, @"utf-8 not supported yet");
        return;
    }

    FFOPushToArray(deletions, 1);
    FFOPushToArray(deletions, slashIdx + 1);
    string[slashIdx] = FFOEscapeCharForChar(string[slashIdx + 1]);
}

/*static char *FFOStringAfterDeletions(char *origString, uint32_t startIdx, uint32_t endIdx, FFOArray *deletions) {
    char *newString = malloc(sizeof(char) * (endIdx - startIdx)); // unused space but oh well
    uint32_t offset = 0;
    uint32_t *elements = deletions->elements;
    FFOPushToArray(deletions, endIdx);
    for (NSInteger i = 0; i < deletions->length - 1; i += 2) {
        uint32_t idx = elements[i];
        uint32_t amountToDelete = elements[i + 1];
        uint32_t nextIdx = elements[i + 2];
        offset += amountToDelete;
        memcpy(origString + idx, newString + idx - offset, );
    }
    newString[endIdx - startIdx - offset] = '\0';
}*/

// ideas:
// use a custom allocator and then at the end send an event saying that they need to clean up and put everything into their own storage
// we could also avoid copying the largest continuous piece of the string that doesn't have any deletions
// copy out into a scratch buffer, then copy back in
// take http:\/\/... for instance. it's actually faster to move the "http://" part forwards than to move the rest of it backwards
static void FFOPerformDeletions(char *string, uint32_t startIdx, uint32_t endIdx, FFOArray *deletions, FFOArray *copyBuffer) {
    uint32_t origLen = endIdx - startIdx;
    if (origLen > copyBuffer->capacity) {
        FFOGrowArray(copyBuffer, origLen);
    }
    uint32_t *copyElements = copyBuffer->elements;
    uint32_t *elements = deletions->elements;
    FFOPushToArray(deletions, endIdx);
    FFOPushToArray(deletions, 0);
    uint32_t prevIdx = 0;
    uint32_t newLen = 0;
    for (NSInteger i = 0; i < deletions->length - 1; i += 2) {
        uint32_t idx = elements[i];
        uint32_t amountToDelete = elements[i + 1];
        // note that for efficiency's sake, we don't update the length of copyBuffer here
        memcpy(copyElements + newLen, string + prevIdx, idx - prevIdx);
        prevIdx = idx + amountToDelete;
        newLen += idx - prevIdx;
    }
    memcpy(string + startIdx, copyElements, newLen);
    string[startIdx +newLen] = '\0';
}

static void FFOJsonParse(char *string, NSInteger length) {
    FFOArray *quoteIdxsArray, *slashIdxsArray;
    FFOArray *copyBuffer = FFOArrayWithCapacity(100);
    FFOCallbacks callbacks = {
        .stringCallback = FFOGotString,
    };
    FFOGatherCharIdxs(string, length, &quoteIdxsArray, &slashIdxsArray);
    FFOPushToArray(quoteIdxsArray, UINT32_MAX);
    uint32_t *quoteIdxs = quoteIdxsArray->elements;
    uint32_t *slashIdxs = slashIdxsArray->elements;
    uint32_t idx = 0;
    NSInteger quoteIdxIdx = 0;
    NSInteger slashIdxIdx = 0;
    uint32_t nextSlashIdx = slashIdxs[slashIdxIdx];
    FFOArray *deletions = FFOArrayWithCapacity(10);
    while (idx < length) {
        switch (string[idx]) {
            case '"':
                quoteIdxIdx++;
                uint32_t stringStartIdx = idx + 1;
                uint32_t nextQuoteIdx = quoteIdxs[quoteIdxIdx];
                while (nextSlashIdx < nextQuoteIdx) {
                    FFOProcessEscapedSequence(deletions, string, nextSlashIdx);
                    nextSlashIdx = slashIdxs[++slashIdxIdx];
                }
                if (deletions->length > 0) {
                    FFOStringAfterDeletions(string, stringStartIdx, nextQuoteIdx, deletions, copyBuffer);
                    deletions->length = 0;
                } else {
                    string[nextQuoteIdx] = '\0';
                    callbacks.stringCallback(string + stringStartIdx);
                    // string[nextQuoteIdx] = '"';
                }
                idx = nextQuoteIdx + 1;
                break;
            case '{':
                callbacks.dictionaryStartCallback();
                break;
            case '}':
                callbacks.dictionaryEndCallback();
                break;
            case '[':
                callbacks.arrayStartCallback();
                break;
            case ']':
                callbacks.arrayEndCallback();
                break;
            case ':':
                break;
            default: { // It's a dictionary key
                char *colonStart = memchr(string + idx + 1, ':', length - idx - 1);
                *colonStart = '\0';
                callbacks.stringCallback(string + idx);
                // *colonStart = ':'
                idx = (uint32_t)(colonStart - string + 1);
                break;
            }
        }
    }
}

static const uint8x16_t sOneVec = {0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80};

static void FFOPopulateVecsForChar(char c, uint8x16_t *lowVec, uint8x16_t *highVec) {
    uint8_t low = 127 - c;
    uint8_t high = 128 - c;

    uint8x16_t lowVecTemp = {low, low, low, low, low, low, low, low, low, low, low, low, low, low, low, low};
    uint8x16_t highVecTemp = {high, high, high, high, high, high, high, high, high, high, high, high, high, high, high, high};
    *lowVec = lowVecTemp;
    *highVec = highVecTemp;
}

static const char *FFOGatherCharIdxs(const char *string, NSInteger length, FFOArray **quoteIdxs, FFOArray **slashIdxs) {
    *quoteIdxs = FFOArrayWithCapacity(length / 10);
    *slashIdxs = FFOArrayWithCapacity(length / 10);

    uint8x16_t lowQuoteVec, highQuoteVec, lowSlashVec, highSlashVec;
    FFOPopulateVecsForChar('"', &lowQuoteVec, &highQuoteVec);
    FFOPopulateVecsForChar('\\', &lowSlashVec, &highSlashVec);


    NSInteger total = length / sizeof(uint8x16_t);
    uint8x16_t *vectors = (uint8x16_t *)string;
    uint8x16_t *end = vectors + total;
    uint8x16_t vector;
    for (; vectors != end; vectors++) {
        vector = *vectors;
        uint8x16_t quoteResult = sOneVec & ((vmvnq_u8(vector + lowQuoteVec)) & (vector + highQuoteVec));
        uint8_t max = vmaxvq_u8(quoteResult);
        if (max != 0) {
            uint64x2_t chunks = vreinterpretq_u64_u8(quoteResult);
            uint64_t chunk = vgetq_lane_u64(chunks, 0);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + lead / 8);
                FFOPushToArray(*quoteIdxs, idx);
            }
            chunk = vgetq_lane_u64(chunks, 1);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + 8 + lead / 8);
                FFOPushToArray(*quoteIdxs, idx);
            }
        }

        uint8x16_t slashResult = sOneVec & ((vmvnq_u8(vector + lowSlashVec)) & (vector + highSlashVec));
        max = vmaxvq_u8(slashResult);
        if (max != 0) {
            uint64x2_t chunks = vreinterpretq_u64_u8(slashResult);
            uint64_t chunk = vgetq_lane_u64(chunks, 0);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + lead / 8);
                FFOPushToArray(*slashIdxs, idx);
            }
            chunk = vgetq_lane_u64(chunks, 1);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + 8 + lead / 8);
                FFOPushToArray(*slashIdxs, idx);
            }
        }
    }
    // todo: last bit at the end

    return NULL;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

    NSString *path = [[NSBundle mainBundle] pathForResource:@"citm_catalog" ofType:@"json"];
    NS_VALID_UNTIL_END_OF_SCOPE NSData *objcData = [[[NSFileManager defaultManager] contentsAtPath:path] mutableCopy];
    char *string = (char *)[objcData bytes];
    NSInteger length = strlen(string);
    FFOJsonParse(string, length);
    NSLog(@"done");
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

@end
