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

FFOJsonEvent *sMyEvents;
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

static void push(FFOJsonType type, void *ptr) {
    if (NO) {
        FFOPrintTypeDescription(type, ptr);
    }
    FFOJsonEvent event = {
        .type = type,
        .ptr = ptr
    };
    sMyEvents[sMyEventCount++] = event;
    if (sMyEventCount == 40) {
        printf("");
    }
}

static void FFOGotNull() {
    push(FFOJsonTypeNull, NULL);
}

static void FFOGotString(char *string) {
    push(FFOJsonTypeString, string);
}

static void FFOGotDictionaryStart() {
    push(FFOJsonTypeStartDict, NULL);
}

static void FFOGotDictionaryEnd() {
    push(FFOJsonTypeEndDict, NULL);
}

static void FFOGotArrayStart() {
    push(FFOJsonTypeStartArray, NULL);
}

static void FFOGotNum(double num) {
    push(FFOJsonTypeNum, NULL);
}

static void FFOGotArrayEnd() {
    push(FFOJsonTypeEndArray, NULL);
}

void FFOTestResults(char *string, uint32_t length) {
    FFOCallbacks callbacks = {
        .stringCallback = FFOGotString,
        .numberCallback = FFOGotNum,
        .arrayStartCallback = FFOGotArrayStart,
        .arrayEndCallback = FFOGotArrayEnd,
        .dictionaryStartCallback = FFOGotDictionaryStart,
        .dictionaryEndCallback = FFOGotDictionaryEnd,
        .nullCallback = FFOGotNull,
    };
    sMyEvents = (FFOJsonEvent *)malloc(5000000 * sizeof(*sMyEvents));
    FFOParseJson(string, length, &callbacks);
}
