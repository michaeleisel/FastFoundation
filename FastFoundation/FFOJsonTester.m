//
//  FFOJsonTester.m
//  FastFoundation
//
//  Created by Michael Eisel on 5/23/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFOJsonTestTypes.h"
#import "FFOJsonParser.h"
#import "FFOEnvironment.h"

FFOJsonEvent sMyEvents[500000];
uint64_t sMyEventCount = 0;

static const char *FFONameForType(FFOJsonType type) {
    switch (type) {
        case FFOJsonTypeNull:
            return "null";
        case FFOJsonTypeBool:
            return "bool";
        case FFOJsonTypeNum:
            return "num";
        case FFOJsonTypeString:
            return "string";
        case FFOJsonTypeStartDict:
            return "start_dict";
        case FFOJsonTypeEndDict:
            return "end_dict";
        case FFOJsonTypeStartArray:
            return "start_array";
        case FFOJsonTypeEndArray:
            return "end_array";
        default:
            return "???";
    }
}

static void FFOPrintTypeDescription(FFOJsonType type, void *ptr) {
    printf("%s", FFONameForType(type)); if (type == FFOJsonTypeString) {
        BOOL leftEarly = NO;
        const char *string = ptr;
        NSInteger maxLen = 20;
        for (NSInteger length = 0; length < maxLen; length++) {
            if (string[length] == '\0') {
                leftEarly = YES;
                break;
            }
        }
        char buffer[maxLen + 3 + 1];
        memcpy(buffer, string, maxLen);
        if (leftEarly) {
            memcpy(buffer + maxLen, "...", 3 + 1 /*null terminator*/);
        }
        printf(": %s", buffer);
    }
    printf("\n");
}

static void push(FFOJsonType type, FFOResult result) {
    if (!FFOIsDebug()) {
        sMyEventCount++;
        return;
    }
    if (NO) {
        // FFOPrintTypeDescription(type, ptr);
    }
    FFOJsonEvent event = {
        .type = type,
        .result = result,
    };
    sMyEvents[sMyEventCount++] = event;
}

static void FFOGotBoolean(bool b) {
    if (!FFOIsDebug()) {
        return;
    }
    FFOResult result = {.d = b};
    push(FFOJsonTypeBool, result);
}

static void FFOGotNull() {
    if (!FFOIsDebug()) {
        return;
    }
    push(FFOJsonTypeNull, kNoResult);
}

static void FFOGotString(char *string) {
    if (!FFOIsDebug()) {
        return;
    }
    FFOResult result = {.str = string};
    push(FFOJsonTypeString, result);
}

static void FFOGotDictionaryStart() {
    if (!FFOIsDebug()) {
        return;
    }
    push(FFOJsonTypeStartDict, kNoResult);
}

static void FFOGotDictionaryEnd() {
    if (!FFOIsDebug()) {
        return;
    }
    push(FFOJsonTypeEndDict, kNoResult);
}

static void FFOGotArrayStart() {
    if (!FFOIsDebug()) {
        sMyEventCount++;
        return;
    }
    push(FFOJsonTypeStartArray, kNoResult);
}

static void FFOGotNum(double num) {
    if (!FFOIsDebug()) {
        sMyEventCount++;
        return;
    }
    FFOResult result;
    result.d = num;
    push(FFOJsonTypeNum, result);
}

static void FFOGotArrayEnd() {
    if (!FFOIsDebug()) {
        sMyEventCount++;
        return;
    }
    push(FFOJsonTypeEndArray, kNoResult);
}

static FFOCallbacks sCallbacks = {
    .stringCallback = FFOGotString,
    .numberCallback = FFOGotNum,
    .arrayStartCallback = FFOGotArrayStart,
    .arrayEndCallback = FFOGotArrayEnd,
    .dictionaryStartCallback = FFOGotDictionaryStart,
    .dictionaryEndCallback = FFOGotDictionaryEnd,
    .nullCallback = FFOGotNull,
    .booleanCallback = FFOGotBoolean,
};

void FFOTestResults(char *string, uint32_t length) {
    FFOParseJson(string, length, &sCallbacks);
}
