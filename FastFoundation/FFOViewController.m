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
// #import <arm_neon.h>
// #import <arm_acle.h>
#import "FFOArray.h"
#import "FFOString.h"
#import "ConvertUTF.h"

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

// static void FFOGatherCharIdxs(const char *string, uint32_t length, FFOArray **quoteIdxs, FFOArray **slashIdxs);

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

static inline unichar FFOUnicharFromHexCode(const char *hexCode) {
    uint32_t shiftAmount = 12;
    unichar u = 0;
    for (NSInteger i = 0; i < 4; i++) {
        char c = hexCode[i];
        uint8_t raw = 0;
        if (c <= '9') {
            raw = c - '0';
        } else {
            raw = tolower(c) - 'a';
        }
        u |= raw << shiftAmount;
        shiftAmount -= 4;
    }
    return u;
}

// We want to skip the next slash if that slash is denoting the low part of a unicode surrogate pair
static inline BOOL/*skip next slash*/ FFOProcessEscapedSequence(FFOArray *deletions, char *string, uint32_t stringLen, uint32_t slashIdx) {
    if (unlikely(slashIdx > stringLen - 2)) {
        FFOPushToArray(deletions, stringLen - slashIdx);
        FFOPushToArray(deletions, slashIdx);
        return NO;
    }

    char afterSlash = string[slashIdx + 1];
    if (afterSlash == 'u' || afterSlash == 'U') {
        if (unlikely(slashIdx > stringLen - 6)) {
            FFOPushToArray(deletions, stringLen - slashIdx);
            FFOPushToArray(deletions, slashIdx);
            return NO;
        }
        unichar uChars[2];
        uChars[0] = FFOUnicharFromHexCode(string + slashIdx + 2);
        uint8_t *targetStart = (uint8_t *)(string + slashIdx);
        memcpy(string + slashIdx, uChars, 2);
        if (UTF16CharIsHighSurrogate(uChars[0]) && slashIdx > stringLen - 12 && string[slashIdx + 6] == '\\' && string[slashIdx + 7] != 'u') {
            uChars[1] = FFOUnicharFromHexCode(string + slashIdx + 8);
            ConvertUTF16toUTF8((const unichar **)&uChars, uChars + 2, &targetStart, targetStart + 4, 0);
            FFOPushToArray(deletions, slashIdx + 4);
            FFOPushToArray(deletions, (6 - 2) * 2);
            return YES;
        } else {
            ConvertUTF16toUTF8((const unichar **)&uChars, uChars + 1, &targetStart, targetStart + 2, 0);
            FFOPushToArray(deletions, slashIdx + 2);
            FFOPushToArray(deletions, 6 - 2);
            return NO;
        }
    }

    FFOPushToArray(deletions, slashIdx + 1);
    FFOPushToArray(deletions, 1);
    string[slashIdx] = FFOEscapeCharForChar(string[slashIdx + 1]);
    return NO;
}

// ideas:
// use a custom allocator and then at the end send an event saying that they need to clean up and put everything into their own storage
// we could also avoid copying the largest continuous piece of the string that doesn't have any deletions
// copy out into a scratch buffer, then copy back in
// take http:\/\/... for instance. it's actually faster to move the "http://" part forwards than to move the rest of it backwards
static void FFOPerformDeletions(char *string, uint32_t startIdx, uint32_t endIdx, FFOArray *deletions, FFOString *copyBuffer) {
    copyBuffer->length = 0;
    FFOPushToArray(deletions, endIdx);
    FFOPushToArray(deletions, 0);
    uint32_t prevIdx = 0;
    uint32_t *elements = deletions->elements;
    for (NSInteger i = 0; i < deletions->length - 1; i += 2) {
        uint32_t idx = elements[i];
        uint32_t amountToDelete = elements[i + 1];
        FFOPushToString(copyBuffer, string + prevIdx, idx - prevIdx);
        prevIdx = idx + amountToDelete;
    }
    memcpy(string + startIdx, copyBuffer->chars, copyBuffer->length);
    string[startIdx + copyBuffer->length] = '\0';
}

static void FFOParseJson(char *string, uint32_t length) {
    FFOArray *quoteIdxsArray, *slashIdxsArray;
    FFOArray *copyBuffer = FFOArrayWithCapacity(100);
    FFOCallbacks callbacks = {
        .stringCallback = FFOGotString,
    };
    FFOGatherCharsNaive(string, length, &quoteIdxsArray, &slashIdxsArray);
    // FFOGatherCharIdxs(string, length, &quoteIdxsArray, &slashIdxsArray);
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
                    FFOProcessEscapedSequence(deletions, string, length, nextSlashIdx);
                    nextSlashIdx = slashIdxs[++slashIdxIdx];
                }
                if (deletions->length > 0) {
                    FFOPerformDeletions(string, stringStartIdx, nextQuoteIdx, deletions, copyBuffer);
                    deletions->length = 0;
                } else {
                    string[nextQuoteIdx] = '\0';
                }
                callbacks.stringCallback(string + stringStartIdx);
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
            default: {
                if ('0' <= string[idx] && string[idx] <= '9') {
                    // It's a number
                } else {
                    // It's a dictionary key
                    char *colonStart = memchr(string + idx + 1, ':', length - idx - 1);
                    *colonStart = '\0';
                    callbacks.stringCallback(string + idx);
                    // *colonStart = ':'
                    idx = (uint32_t)(colonStart - string + 1);
                }
            }
        }
    }

    // todo: free the FFOArrays here
}

/*static const uint8x16_t sOneVec = {0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80};

static void FFOPopulateVecsForChar(char c, uint8x16_t *lowVec, uint8x16_t *highVec) {
    uint8_t low = 127 - c;
    uint8_t high = 128 - c;

    uint8x16_t lowVecTemp = {low, low, low, low, low, low, low, low, low, low, low, low, low, low, low, low};
    uint8x16_t highVecTemp = {high, high, high, high, high, high, high, high, high, high, high, high, high, high, high, high};
    *lowVec = lowVecTemp;
    *highVec = highVecTemp;
}*/

static void FFOGatherCharsNaive(const char *string, uint32_t length, FFOArray **quoteIdxsPtr, FFOArray **slashIdxsPtr) {
    FFOArray *quoteIdxs = FFOArrayWithCapacity(1);
    FFOArray *slashIdxs = FFOArrayWithCapacity(1);
    for (NSInteger i = 0; i < length; i++) {
        if (string[i] == '"') {
            FFOPushToArray(quoteIdxs, (uint32_t)i);
        } else if (string[i] == '\\') {
            FFOPushToArray(slashIdxs, (uint32_t)i);
        }
    }
    *quoteIdxsPtr = quoteIdxs;
    *slashIdxsPtr = slashIdxs;
}

- (void)_testGatherCharIdxsWithString:(const char *)string
{
    FFOArray *testQuoteIdxs;
    FFOArray *testSlashIdxs;
    NSInteger length = strlen(string);
    NSAssert(NO, @"");//FFOGatherCharsNaive(string, (uint32_t)length, &testQuoteIdxs, &testSlashIdxs);
    FFOArray *expectedQuoteIdxs = FFOArrayWithCapacity(1);
    FFOArray *expectedSlashIdxs = FFOArrayWithCapacity(1);
    for (NSInteger i = 0; i < length; i++) {
        if (string[i] == '"') {
            FFOPushToArray(expectedQuoteIdxs, (uint32_t)i);
        } else if (string[i] == '\\') {
            FFOPushToArray(expectedSlashIdxs, (uint32_t)i);
        }
    }
    NSAssert(FFOArraysAreEqual(testQuoteIdxs, expectedQuoteIdxs), @"");
    NSAssert(FFOArraysAreEqual(testSlashIdxs, expectedSlashIdxs), @"");
}

- (void)_testGatherCharIdxs
{
    [self _testGatherCharIdxsWithString:""];
    [self _testGatherCharIdxsWithString:"\""];
    [self _testGatherCharIdxsWithString:"\"\\"];
    [self _testGatherCharIdxsWithString:" \""];
    [self _testGatherCharIdxsWithString:" \" "];
    [self _testGatherCharIdxsWithString:"\"\"              "];
    [self _testGatherCharIdxsWithString:"                  \"\""];
    [self _testGatherCharIdxsWithString:"                  \"\"   \\ \\   adsf adsf \"  \"   \\   "];
}

- (void)_testPerformDeletions
{
    for (NSArray <id>*piece in @[
          @[@"abcdefghijklm", @"adefklm", @[@1, @2], @[@6, @4]],
          @[@"abcd", @"abcd"],
          @[@"abcd", @"", @[@0, @1], @[@1, @3]],
          @[@"", @""],
          @[@"a", @"", @[@0, @1]],
          @[@"abcdefghijklm", @"adefklm", @[@1, @2], @[@6, @4]]]) {
        char *result;
        asprintf(&result, [piece[0] UTF8String]);
        FFOString *copyBuffer = FFOStringWithCapacity(1);
        FFOArray *deletions = FFOArrayWithCapacity(1);
        for (NSArray <NSNumber *>*pair in [piece subarrayWithRange:NSMakeRange(2, piece.count - 2)]) {
            FFOPushToArray(deletions, [pair[0] unsignedIntValue]);
            FFOPushToArray(deletions, [pair[1] unsignedIntValue]);
        }
        FFOPerformDeletions(result, 0, (uint32_t)strlen(result), deletions, copyBuffer);
        NSAssert(0 == strcmp(result, [piece[1] UTF8String]), @"");
        FFOFreeArray(deletions);
        FFOFreeString(copyBuffer);
        free(result);
    }
}

- (void)_testParseJson
{
    FFOArray *deletions = FFOArrayWithCapacity(1);
    for (NSInteger i = 1; i <= 2; i++) {
        NSString *name = [NSString stringWithFormat:@"j%zd", i];
        NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"json"];
        NS_VALID_UNTIL_END_OF_SCOPE NSData *objcData = [[[NSFileManager defaultManager] contentsAtPath:path] mutableCopy];
        char *string = (char *)[objcData bytes];
    }
}

- (void)_runTests
{
    // todo: test non-ascii chars
    // [self _testGatherCharIdxs];
    [self _testPerformDeletions];
    [self _testParseJson];
    NSLog(@"tests pass");
}

/*static void FFOGatherCharIdxs(const char *string, uint32_t length, FFOArray **quoteIdxsPtr, FFOArray **slashIdxsPtr) {
    FFOArray *quoteIdxs = FFOArrayWithCapacity(length / 10);
    FFOArray *slashIdxs = FFOArrayWithCapacity(length / 10);

    uint8x16_t lowQuoteVec, highQuoteVec, lowSlashVec, highSlashVec;
    FFOPopulateVecsForChar('"', &lowQuoteVec, &highQuoteVec);
    FFOPopulateVecsForChar('\\', &lowSlashVec, &highSlashVec);

    uint32_t total = length / sizeof(uint8x16_t);
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
                FFOPushToArray(quoteIdxs, idx);
            }
            chunk = vgetq_lane_u64(chunks, 1);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + 8 + lead / 8);
                FFOPushToArray(quoteIdxs, idx);
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
                FFOPushToArray(slashIdxs, idx);
            }
            chunk = vgetq_lane_u64(chunks, 1);
            if (chunk != 0) {
                uint64_t lead = __clzll(__rbitll(chunk));
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + 8 + lead / 8);
                FFOPushToArray(slashIdxs, idx);
            }
        }
    }

    // Do the bit at the end
    for (uint32_t i = length - length % sizeof(uint8x16_t); i < length; i++) {
        if (string[i] == '"') {
            FFOPushToArray(quoteIdxs, i);
        } else if (string [i] == '\\'){
            FFOPushToArray(slashIdxs, i);
        }
    }

    *slashIdxsPtr = slashIdxs;
    *quoteIdxsPtr = quoteIdxs;
}*/

- (void)viewDidLoad
{
	[super viewDidLoad];
    [self _runTests];
    return;

    NSString *path = [[NSBundle mainBundle] pathForResource:@"citm_catalog" ofType:@"json"];
    NS_VALID_UNTIL_END_OF_SCOPE NSData *objcData = [[[NSFileManager defaultManager] contentsAtPath:path] mutableCopy];
    char *string = (char *)[objcData bytes];
    NSInteger length = strlen(string);
    FFOParseJson(string, (uint32_t)length);
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

/*__used static void printVec(uint8x16_t vec) {
    for (NSInteger i = 0; i < sizeof(uint8x16_t); i++) {
        printf("%zd, ", (NSInteger)vec[i]);
    }
    printf("\n");
}*/

__used static void printBinaryRep(uint64_t num) {
    for (NSInteger i = 0; i < sizeof(num) * 8; i++) {
        printf("%zd", (num >> (63 - i)) & 1);
    }
    printf("\n");
}

@end
