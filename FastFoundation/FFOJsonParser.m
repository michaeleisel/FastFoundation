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

#ifndef RAPIDJSON_UINT64_C2
#define RAPIDJSON_UINT64_C2(high32, low32) (((uint64_t)(high32) << 32) | (uint64_t)(low32))
#endif

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
        case 'r':
            return '\r';
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
static void FFOPerformDeletions(char *string, uint32_t startIdx, uint32_t endIdx, FFOArray *deletions) {
    FFOPushToArray(deletions, endIdx);
    FFOPushToArray(deletions, 0);
    uint32_t prevIdx = startIdx;
    uint32_t *elements = deletions->elements;
    uint32_t amountCopied = 0;
    for (NSInteger i = 0; i < deletions->length - 1; i += 2) {
        uint32_t idx = elements[i];
        uint32_t amountToDelete = elements[i + 1];
        uint32_t length = idx - prevIdx;
        memmove(string + startIdx + amountCopied, string + prevIdx, length);
        amountCopied += length;
        prevIdx = idx + amountToDelete;
    }
    string[startIdx + amountCopied] = '\0';
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

static inline void FFOGatherForVec(FFOArray *idxs, uint32_t offset, uint64_t low, uint64_t high) {
    while (low != 0) {
        int lz =__builtin_clzll(low);
        FFOPushToArray(idxs, offset + (lz >> 3));
        low &= low == 255 ? 0 : (~0ULL) >> (lz + 8);
        // char shiftWidth = (64 - lz + 8);
        // low = (low << shiftWidth) >> shiftWidth;
    }
    while (high != 0) {
        int lz =__builtin_clzll(high);
        FFOPushToArray(idxs, offset + 8 + (lz >> 3));
        high &= high == 255 ? 0 : ((~0ULL) >> (lz + 8));
        // char shiftWidth = (64 - lz + 8);
        // high = (high << shiftWidth) >> shiftWidth;
    }
}

void FFOGatherCharIdxs(const char *string, uint32_t length, FFOArray **quoteIdxsPtr, FFOArray **slashIdxsPtr) {
    FFOArray *quoteIdxs = FFOArrayWithCapacity(length / 10);
    FFOArray *slashIdxs = FFOArrayWithCapacity(length / 10);
    *slashIdxsPtr = slashIdxs;
    *quoteIdxsPtr = quoteIdxs;

    const uint8x16_t quotes = vmovq_n_u8('"');
    const uint8x16_t slashes = vmovq_n_u8('\\');

    const char *end = string + length;
    const char *alignStart = ((ptrdiff_t)string % 16 == 0) ? string : (string - ((ptrdiff_t)string % 16) + 16);
    const char *alignEnd = end - ((ptrdiff_t)end % 16);
    if (alignEnd < alignStart) {
        alignEnd = alignStart;
    }
    const char *p = NULL;
    for (p = string; p < alignStart && p < end; p++) {
        if (*p == '"') {
            FFOPushToArray(quoteIdxs, (uint32_t)(p - string));
        } else if (*p == '\\'){
            FFOPushToArray(slashIdxs, (uint32_t)(p - string));
        }
    }
    if (p == end) {
        return;
    }
    for (const char *p = alignStart; p != alignEnd; p += 16) {
        const uint8x16_t s = vld1q_u8((const uint8_t *)(p));
        uint8x16_t x = vceqq_u8(s, quotes);
        uint8x16_t y = vceqq_u8(s, slashes);

        x = vrev64q_u8(x);                     // Rev in 64
        y = vrev64q_u8(y);                     // Rev in 64
        uint64_t lowQuotes = vgetq_lane_u64((uint64x2_t)x, 0);   // extract
        uint64_t highQuotes = vgetq_lane_u64((uint64x2_t)x, 1);  // extract
        uint64_t lowSlashes = vgetq_lane_u64((uint64x2_t)y, 0);   // extract
        uint64_t highSlashes = vgetq_lane_u64((uint64x2_t)y, 1);  // extract

        FFOGatherForVec(quoteIdxs, (uint32_t)(p - string), lowQuotes, highQuotes);
        FFOGatherForVec(slashIdxs, (uint32_t)(p - string), lowSlashes, highSlashes);
    }

     // Do the bit at the end
    for (p = alignEnd; p != end; p++) {
        if (*p == '"') {
            FFOPushToArray(quoteIdxs, (uint32_t)(p - string));
        } else if (*p == '\\'){
            FFOPushToArray(slashIdxs, (uint32_t)(p - string));
        }
    }
 }

static inline BOOL FFOConsume(const char *string, uint32_t *idx, char c) {
    if (string[*idx] == c) {
        (*idx)++;
        return YES;
    } else {
        return NO;
    }
}

static void FFOParseError(int i, uint32_t idx) {
    printf("fail\n");
}

static inline uint32_t FFOParseNumber(char *string, FFOCallbacks *callbacks) {
    uint32_t endIdx = 1;
    for (;; endIdx++) {
        char c = string[endIdx];
        if (isnumber(c)) {
            continue;
        } else if (c == '.' || c == 'e' || c == 'E' || c == 'i' || c == 'I') {
            continue;
            assert("not supported" && NO);
        } else {
            break;
        }
    }
    /*int64_t num = 0;
    for (NSInteger i = 0; i < endIdx; i++) {
        num = num * 10 + string[i] - '0';
    }*/
    callbacks->numberCallback(0);
    return endIdx;
}

static void FFORemoveDoubleSlashIdxs(FFOArray *slashIdxs) {
    uint32_t end = (uint32_t)(slashIdxs->length - 1);
    uint32_t *idxs = slashIdxs->elements;
    uint32_t amountToDelete = 0;
    for (uint32_t i = 0; i < end; i++) {
        idxs[i - amountToDelete] = idxs[i];
        if (idxs[i] + 1 == idxs[i + 1]) {
            amountToDelete++;
            i++;
        }
    }
    idxs[end - amountToDelete] = idxs[end];
    slashIdxs->length -= amountToDelete;
}

__attribute__((noinline)) void FFOParseJson(char *string, uint32_t length, FFOCallbacks *callbacks) {
    FFOArray *quoteIdxsArray, *slashIdxsArray;
    // FFOGatherCharsNaive(string, length, &quoteIdxsArray, &slashIdxsArray);
    FFOGatherCharIdxs(string, length, &quoteIdxsArray, &slashIdxsArray);
    FFORemoveDoubleSlashIdxs(slashIdxsArray);
    /*FFOPushToArray(quoteIdxsArray, UINT32_MAX);
    uint32_t *quoteIdxs = quoteIdxsArray->elements;
    uint32_t *slashIdxs = slashIdxsArray->elements;
    uint32_t idx = 0;
    NSInteger quoteIdxIdx = 0;
    NSInteger slashIdxIdx = 0;
    uint32_t nextSlashIdx = slashIdxs[slashIdxIdx];
    FFOArray *deletions = FFOArrayWithCapacity(10);
    BOOL nextStringIsAKey = NO;
    while (idx < length) {
        char c = string[idx];
        switch (c) {
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
                    FFOPerformDeletions(string, stringStartIdx, nextQuoteIdx, deletions);
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
                if (c == ',') {
                    // skip
                } else if (('A' <= c && c <= 'Z') || ('a' <= c && c <= 'z')) {
                    // It's a dictionary key
                    if (nextStringIsAKey) {
                        char *colonStart = memchr(string + idx + 1, ':', length - idx - 1);
                        *colonStart = '\0';
                        callbacks->stringCallback(string + idx);
                        // *colonStart = ':'
                        idx = (uint32_t)(colonStart - string);
                    } else if (c == 'f') {
                        assert(0 == memcmp(string + idx, "false", 5) && !isalnum(string[idx + 5]));
                        callbacks->boolCallback(false);
                        idx += 5;
                    } else if (c == 't') {
                        assert(0 == memcmp(string + idx, "true", 4) && !isalnum(string[idx + 4]));
                        callbacks->boolCallback(true);
                        idx += 4;
                    } else {
                        // It's null
                        assert(0 == memcmp(string + idx, "null", 4) && !isalnum(string[idx + 4]));
                        callbacks->nullCallback();
                        idx += 4;
                    }
                } else {
                    // It's a number
                    idx += FFOParseNumber(string + idx, callbacks) - 1;
                }
            }
        }
        idx++;
    }

    FFOFreeArray(deletions);*/
    FFOFreeArray(quoteIdxsArray);
    FFOFreeArray(slashIdxsArray);

    // todo: free the FFOArrays here
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
    /*printf(<#const char *restrict, ...#>)
    printf("%d, %d, %d", testQuoteIdxs->length, expectedQuoteIdxs->length)*/
    NSCAssert(FFOArraysAreEqual(testQuoteIdxs, expectedQuoteIdxs), @"");
    NSCAssert(FFOArraysAreEqual(testSlashIdxs, expectedSlashIdxs), @"");
}

static void FFOTestGatherCharIdxs()
{
    FFOTestGatherCharIdxsWithString("                  \"\"   \\ \\   adsf adsf \"  \"   \\   ");
    FFOTestGatherCharIdxsWithString("\"");
    FFOTestGatherCharIdxsWithString("\"\"              ");
    FFOTestGatherCharIdxsWithString("");
    FFOTestGatherCharIdxsWithString("\"\\");
    FFOTestGatherCharIdxsWithString(" \"");
    FFOTestGatherCharIdxsWithString(" \" ");
    FFOTestGatherCharIdxsWithString("                  \"\"");
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
        asprintf(&result, "%s", [piece[0] UTF8String]);
        FFOArray *deletions = FFOArrayWithCapacity(1);
        for (NSArray <NSNumber *>*pair in [piece subarrayWithRange:NSMakeRange(2, piece.count - 2)]) {
            FFOPushToArray(deletions, [pair[0] unsignedIntValue]);
            FFOPushToArray(deletions, [pair[1] unsignedIntValue]);
        }
        FFOPerformDeletions(result, 0, (uint32_t)strlen(result), deletions);
        NSCAssert(0 == strcmp(result, [piece[1] UTF8String]), @"");
        FFOFreeArray(deletions);
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
