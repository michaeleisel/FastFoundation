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
#import "vectorizer.h"
#import <arm_acle.h>
#import <mach-o/dyld.h>

typedef unsigned char byte;

#ifndef RAPIDJSON_UINT64_C2
#define RAPIDJSON_UINT64_C2(high32, low32) (((uint64_t)(high32) << 32) | (uint64_t)(low32))
#endif

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
static inline uint32_t/*skip next slash*/ FFOProcessEscapedSequence(FFOArray *deletions, char *string, uint32_t stringLen, uint32_t slashIdx) {
    if (unlikely(slashIdx > stringLen - 2)) {
        FFOPushToArray(deletions, stringLen - slashIdx);
        FFOPushToArray(deletions, slashIdx);
        return 0;
    }

    char afterSlash = string[slashIdx + 1];
    if (afterSlash == 'u' || afterSlash == 'U') {
        if (unlikely(slashIdx > stringLen - 6)) {
            FFOPushToArray(deletions, stringLen - slashIdx);
            FFOPushToArray(deletions, slashIdx);
            return 0;
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
            return 12;
        } else {
            ConvertUTF16toUTF8((const unichar **)&uChars, uChars + 1, &targetStart, targetStart + 2, 0);
            FFOPushToArray(deletions, slashIdx + 2);
            FFOPushToArray(deletions, 6 - 2);
            return 6;
        }
    }

    FFOPushToArray(deletions, slashIdx + 1);
    FFOPushToArray(deletions, 1);
    string[slashIdx] = FFOEscapeCharForChar(string[slashIdx + 1]);
    return 2;
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
            assert("not supported" && NO);
        } else {
            break;
        }
    }
    int64_t num = 0;
    for (NSInteger i = 0; i < endIdx; i++) {
        num = num * 10 + string[i] - '0';
    }
    callbacks->numberCallback(num);
    return endIdx;
}

__used static void pp(char *str) {
    for (NSInteger i = 0; i < 500; i++) {
        printf("%c", str[i]);
    }
    printf("\n");
}

void FFOParseJson(char *string, uint32_t length, FFOCallbacks *callbacks) {
    FFOString *copyBuffer = FFOStringWithCapacity(100);
    uint32_t destLen = length / 8;
    byte *dest = malloc(destLen);
    process_chars(string, length, dest);
    BOOL inDictionary = NO;
    uint32_t idx = 0;
    uint32_t specialIdx = 0;
    FFOArray *deletions = FFOArrayWithCapacity(10);
    BOOL nextStringIsAKey = NO;
    while (idx < length) {
        switch (string[idx]) {
            case '"': {
                uint32_t startIdx = idx + 1;
                if (startIdx == 41683) {
                    ;
                }
                uint32_t destIdx = startIdx >> 3;
                uint32_t offset = startIdx & 0x7;
                byte b = dest[destIdx] << offset;
                // todo: separate list for strings?
                BOOL hitEnd = NO;
                while (destIdx < destLen) {
                    while (b) {
                        // if __clz is slow, use a lookup table instead
                        uint32_t next = __clz(b) - 24 + 1;
                        offset += next;
                        b = b << next;
                        // Offset could be 8, so use "+" and not "|"
                        specialIdx = ((destIdx << 3) + offset) - 1;
                        char c = string[specialIdx];
                        if (c == '"') {
                            hitEnd = YES;
                            break;
                        } else if (c == '\\') {
                            uint32_t extraOffset = -1 + FFOProcessEscapedSequence(deletions, string, length, specialIdx);
                            b = b << extraOffset;
                            offset += extraOffset;
                            // Handles overflow
                            if (offset >= 8) {
                                destIdx += offset >> 3;
                                offset = offset & 0x7;
                                b = dest[destIdx] << offset;
                            }
                        }
                    }
                    if (hitEnd) {
                        break;
                    }
                    offset = 0;
                    destIdx++;
                    b = dest[destIdx];
                }
                idx = specialIdx;
                if (deletions->length > 0) {
                    FFOPerformDeletions(string, startIdx, idx, deletions, copyBuffer);
                    deletions->length = 0;
                } else {
                    string[idx] = '\0';
                }
                // printf("%s\n", string + startIdx);
                callbacks->stringCallback(string + startIdx);
            }
                break;
            case '{':
                nextStringIsAKey = YES;
                callbacks->dictionaryStartCallback();
                inDictionary = YES;
                break;
            case '}':
                callbacks->dictionaryEndCallback();
                break;
            case '[':
                callbacks->arrayStartCallback();
                inDictionary = NO;
                break;
            case ']':
                callbacks->arrayEndCallback();
                break;
            case ',':
                nextStringIsAKey = inDictionary;
                break;
            case ':':
                nextStringIsAKey = NO;
                break;
            case 'f':
                idx += 4;
                callbacks->booleanCallback(NO);
                break;
            case 't':
                idx += 3;
                callbacks->booleanCallback(YES);
                break;
            case 'n':
                idx += 3;
                callbacks->nullCallback();
                break;
            default: {
                // todo: deal with when null or undefined is the key
                // todo: can keys start with something for which isalpha is false, e.g. a number?
                if (isalpha(string[idx])) {
                    // todo: add skips here
                    // It's a dictionary key
                    if (nextStringIsAKey) {
                        char *colonStart = memchr(string + idx + 1, ':', length - idx - 1);
                        *colonStart = '\0';
                        callbacks->stringCallback(string + idx);
                        // *colonStart = ':'
                        idx = (uint32_t)(colonStart - string);
                    }
                } else {
                    // It's a number
                    idx += FFOParseNumber(string + idx, callbacks) - 1;
                }
            }
        }
        idx++;
    }

    // todo: free the FFOArrays here
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
    FFOTestPerformDeletions();
    printf("tests pass\n");
}

__used static void printBinaryRep(uint64_t num) {
    for (NSInteger i = 0; i < sizeof(num) * 8; i++) {
        printf("%zd", (num >> (63 - i)) & 1);
    }
    printf("\n");
}
