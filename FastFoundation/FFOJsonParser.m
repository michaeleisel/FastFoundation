//
//  FFOJsonParser.m
//  FastFoundation
//
//  Created by Michael Eisel on 5/23/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#import "FFOJsonParser.h"
#import "FFOArray.h"
#import "FFOString.h"
#import "ConvertUTF.h"
#import <arm_neon.h>
#import <arm_acle.h>

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
    uint32_t prevIdx = startIdx;
    uint32_t *elements = deletions->elements;
    for (NSInteger i = 0; i < deletions->length - 1; i += 2) {
        uint32_t idx = elements[i];
        uint32_t amountToDelete = elements[i + 1];
        // todo: consider just using memmove
        FFOPushToString(copyBuffer, string + prevIdx, idx - prevIdx);
        prevIdx = idx + amountToDelete;
    }
    memcpy(string + startIdx, copyBuffer->chars, copyBuffer->length);
    string[startIdx + copyBuffer->length] = '\0';
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

void FFOGatherCharIdxs(const char *string, uint32_t length, FFOArray **quoteIdxsPtr, FFOArray **slashIdxsPtr) {
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
            uint64_t chunk = __rbitll(vgetq_lane_u64(chunks, 0));
            while (chunk != 0) {
                uint64_t lead = __clzll(chunk);
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + lead / 8);
                FFOPushToArray(quoteIdxs, idx);
                chunk &= ~(1ULL << (63 - lead));
            }
            chunk = __rbitll(vgetq_lane_u64(chunks, 1));
            while (chunk != 0) {
                uint64_t lead = __clzll(chunk);
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + 8 + lead / 8);
                FFOPushToArray(quoteIdxs, idx);
                chunk &= ~(1ULL << (63 - lead));
            }
        }

        uint8x16_t slashResult = sOneVec & ((vmvnq_u8(vector + lowSlashVec)) & (vector + highSlashVec));
        max = vmaxvq_u8(slashResult);
        if (max != 0) {
            uint64x2_t chunks = vreinterpretq_u64_u8(slashResult);
            uint64_t chunk = __rbitll(vgetq_lane_u64(chunks, 0));
            while (chunk != 0) {
                uint64_t lead = __clzll(chunk);
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + lead / 8);
                FFOPushToArray(slashIdxs, idx);
                chunk &= ~(1ULL << (63 - lead));
            }
            chunk = __rbitll(vgetq_lane_u64(chunks, 1));
            while (chunk != 0) {
                uint64_t lead = __clzll(chunk);
                uint32_t idx =  (uint32_t)(((const char *)vectors - string) + 8 + lead / 8);
                FFOPushToArray(slashIdxs, idx);
                chunk &= ~(1ULL << (63 - lead));
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
 }


void FFOParseJson(char *string, uint32_t length, FFOCallbacks *callbacks) {
    FFOArray *quoteIdxsArray, *slashIdxsArray;
    FFOString *copyBuffer = FFOStringWithCapacity(100);
    // FFOGatherCharsNaive(string, length, &quoteIdxsArray, &slashIdxsArray);
    FFOGatherCharIdxs(string, length, &quoteIdxsArray, &slashIdxsArray);
    FFOPushToArray(quoteIdxsArray, UINT32_MAX);
    uint32_t *quoteIdxs = quoteIdxsArray->elements;
    uint32_t *slashIdxs = slashIdxsArray->elements;
    uint32_t idx = 0;
    NSInteger quoteIdxIdx = 0;
    NSInteger slashIdxIdx = 0;
    uint32_t nextSlashIdx = slashIdxs[slashIdxIdx];
    FFOArray *deletions = FFOArrayWithCapacity(10);
    BOOL nextStringIsAKey = NO;
    while (idx < length) {
        switch (string[idx]) {
            case '"':
                quoteIdxIdx++;
                uint32_t stringStartIdx = idx + 1;
                uint32_t nextQuoteIdx = quoteIdxs[quoteIdxIdx];
                while (slashIdxIdx < slashIdxsArray->length && nextSlashIdx < nextQuoteIdx) {
                    if (string[nextSlashIdx + 1] == '"') {
                        nextQuoteIdx = quoteIdxs[++quoteIdxIdx];
                    }
                    BOOL skip = FFOProcessEscapedSequence(deletions, string, length, nextSlashIdx);
                    if (unlikely(skip)) {
                        slashIdxIdx++;
                    }
                    nextSlashIdx = slashIdxs[++slashIdxIdx];
                }
                if (deletions->length > 0) {
                    FFOPerformDeletions(string, stringStartIdx, nextQuoteIdx, deletions, copyBuffer);
                    deletions->length = 0;
                } else {
                    string[nextQuoteIdx] = '\0';
                }
                callbacks->stringCallback(string + stringStartIdx);
                nextStringIsAKey = !nextStringIsAKey;
                quoteIdxIdx++;
                idx = nextQuoteIdx; // will be incremented at the end of the loop
                break;
            case '{':
                nextStringIsAKey = YES;
                callbacks->dictionaryStartCallback();
                break;
            case '}':
                callbacks->dictionaryEndCallback();
                break;
            case '[':
                callbacks->arrayStartCallback();
                break;
            case ']':
                callbacks->arrayEndCallback();
                break;
            case ',':
                nextStringIsAKey = YES;
            case ':':
                nextStringIsAKey = NO;
                break;
            default: {
                // todo: deal with when null or undefined is the key
                if (string[idx] == ',') {
                    // skip
                } else if (isnumber(string[idx])) {
                    // It's a number
                    callbacks->numberCallback(-28);
                    idx++;
                    while (/*length check needed here, and more robust float handling*/string[idx] != '.' && isnumber(string[idx])) {
                        idx++;
                    }
                    idx--;
                } else {
                    // It's a dictionary key
                    if (nextStringIsAKey) {
                        char *colonStart = memchr(string + idx + 1, ':', length - idx - 1);
                        *colonStart = '\0';
                        callbacks->stringCallback(string + idx);
                        // *colonStart = ':'
                        idx = (uint32_t)(colonStart - string);
                    } else {
                        // It's null
                        assert(0 == memcmp(string + idx, "null", 4) && !isalnum(string[idx + 4]));
                        callbacks->nullCallback();
                        idx += 4;
                    }
                }
            }
        }
        idx++;
    }

    // todo: free the FFOArrays here
}

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

static void FFOTestGatherCharIdxsWithString(const char *string)
{
    FFOArray *testQuoteIdxs;
    FFOArray *testSlashIdxs;
    NSInteger length = strlen(string);
    FFOGatherCharIdxs(string, (uint32_t)length, &testQuoteIdxs, &testSlashIdxs);
    FFOArray *expectedQuoteIdxs = FFOArrayWithCapacity(1);
    FFOArray *expectedSlashIdxs = FFOArrayWithCapacity(1);
    for (NSInteger i = 0; i < length; i++) {
        if (string[i] == '"') {
            FFOPushToArray(expectedQuoteIdxs, (uint32_t)i);
        } else if (string[i] == '\\') {
            FFOPushToArray(expectedSlashIdxs, (uint32_t)i);
        }
    }
    NSCAssert(FFOArraysAreEqual(testQuoteIdxs, expectedQuoteIdxs), @"");
    NSCAssert(FFOArraysAreEqual(testSlashIdxs, expectedSlashIdxs), @"");
}

static void FFOTestGatherCharIdxs()
{
    FFOTestGatherCharIdxsWithString("\"\"              ");
    FFOTestGatherCharIdxsWithString("");
    FFOTestGatherCharIdxsWithString("\"");
    FFOTestGatherCharIdxsWithString("\"\\");
    FFOTestGatherCharIdxsWithString(" \"");
    FFOTestGatherCharIdxsWithString(" \" ");
    FFOTestGatherCharIdxsWithString("                  \"\"");
    FFOTestGatherCharIdxsWithString("                  \"\"   \\ \\   adsf adsf \"  \"   \\   ");
}

static void FFOTestPerformDeletions()
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
        NSCAssert(0 == strcmp(result, [piece[1] UTF8String]), @"");
        FFOFreeArray(deletions);
        FFOFreeString(copyBuffer);
        free(result);
    }
}

void FFORunTests()
{
    // todo: test non-ascii chars
    FFOTestGatherCharIdxs();
    FFOTestPerformDeletions();
    printf("tests pass\n");
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
