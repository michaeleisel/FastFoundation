//
//  FFORapidJsonTester.cpp
//  FastFoundation
//
//  Created by Michael Eisel on 5/23/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#include <stdio.h>

#if defined(__SSE4_2__)
#  define RAPIDJSON_SSE42
#elif defined(__SSE2__)
#  define RAPIDJSON_SSE2
#elif defined(__ARM_NEON)
#  define RAPIDJSON_NEON
#endif
    #import "reader.h" // make sure to have the defines before this
#import <iostream>
#import "FFOJsonTestTypes.h"
#import "FFOEnvironment.h"

using namespace rapidjson;
using namespace std;

FFOJsonEvent *sEvents;
uint64_t sEventCount = 0;

static void pushResult(FFOJsonType type, FFOResult result) {
    if (!FFOIsDebug()) {
        sEventCount++;
        return;
    }
    FFOJsonEvent event = {.type = type, .result = result};
    sEvents[sEventCount++] = event;
}

static void push(FFOJsonType type) {
    if (!FFOIsDebug()) {
        sEventCount++;
        return;
    }
    pushResult(type, kNoResult);
}

static void pushNum(FFOJsonType type, double d) {
    if (!FFOIsDebug()) {
        sEventCount++;
        return;
    }
    FFOResult result = {.d = d};
    pushResult(type, result);
}

static void pushString(FFOJsonType type, const char *ptr) {
    if (!FFOIsDebug()) {
        sEventCount++;
        return;
    }
    if (ptr != NULL) {
        char *oldStr = (char *)ptr;
        char *newStr = NULL;
        asprintf(&newStr, "%s", oldStr);
        ptr = newStr;
    }
    FFOResult result = {.str = (const char *)ptr};
    pushResult(type, result);
}

uint64_t sTotal = 0;

struct MyHandler : public BaseReaderHandler<UTF8<>, MyHandler> {
    bool Null() { push(FFOJsonTypeNull); return true; }
    bool Bool(bool b) { push(FFOJsonTypeBool); return true; }
    bool Int(int i) {
        pushNum(FFOJsonTypeNum, i); return true;
    }
    bool Uint(unsigned u) {
        pushNum(FFOJsonTypeNum, u); return true;
    }
    bool Int64(int64_t i) {
        pushNum(FFOJsonTypeNum, i); return true;
    }
    bool Uint64(uint64_t u) {
        pushNum(FFOJsonTypeNum, u); return true;
    }
    bool Double(double d) {
        pushNum(FFOJsonTypeNum, d); return true;
    }
    bool String(const char* str, SizeType length, bool copy) {
        pushString(FFOJsonTypeString, str);
        return true;
    }
    bool StartObject() { push(FFOJsonTypeStartDict); return true; }
    bool Key(const char* str, SizeType length, bool copy) {
        pushString(FFOJsonTypeString, str);
        return true;
    }
    bool EndObject(SizeType memberCount) { push(FFOJsonTypeEndDict); return true; }
    bool StartArray() { push(FFOJsonTypeStartArray); return true; }
    bool EndArray(SizeType elementCount) { push(FFOJsonTypeEndArray); return true; }
};

extern "C" void gooo(char *json) {
    bool insitu = true;
    if (FFOIsDebug()) {
        sEvents = (FFOJsonEvent *)malloc(5000000 * sizeof(*sEvents));
    }
    MyHandler handler;
    Reader reader;
    if (insitu) {
        InsituStringStream ss(json);
        reader.Parse<kParseInsituFlag>(ss, handler);
    } else {
        StringStream ss(json);
        reader.Parse(ss, handler);
    }
}
