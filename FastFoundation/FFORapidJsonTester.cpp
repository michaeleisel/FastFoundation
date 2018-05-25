//
//  FFORapidJsonTester.cpp
//  FastFoundation
//
//  Created by Michael Eisel on 5/23/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#include <stdio.h>

#import "reader.h"
#import <iostream>
#import "FFOJsonTestTypes.h"

using namespace rapidjson;
using namespace std;

FFOJsonEvent *sEvents;
uint64_t sEventCount = 0;

static void push(FFOJsonType type, void *ptr) {
    if (ptr != NULL) {
        char *oldStr = (char *)ptr;
        char *newStr = NULL;
        asprintf(&newStr, "%s", oldStr);
        ptr = newStr;
    }
    FFOJsonEvent event = {
        .type = type,
        .ptr = ptr,
    };
    sEvents[sEventCount++] = event;
}

uint64_t sTotal = 0;

struct MyHandler : public BaseReaderHandler<UTF8<>, MyHandler> {
    bool Null() { push(FFOJsonTypeNull, NULL); return true; }
    bool Bool(bool b) { push(FFOJsonTypeBool, NULL); return true; }
    bool Int(int i) { push(FFOJsonTypeNum, NULL); return true; }
    bool Uint(unsigned u) { push(FFOJsonTypeNum, NULL); return true; }
    bool Int64(int64_t i) { push(FFOJsonTypeNum, NULL); return true; }
    bool Uint64(uint64_t u) { push(FFOJsonTypeNum, NULL); return true; }
    bool Double(double d) { push(FFOJsonTypeNum, NULL); return true; }
    bool String(const char* str, SizeType length, bool copy) {
        push(FFOJsonTypeString, (void *)str);
        return true;
    }
    bool StartObject() { push(FFOJsonTypeStartDict, NULL); return true; }
    bool Key(const char* str, SizeType length, bool copy) {
        push(FFOJsonTypeString, (void *)str);
        return true;
    }
    bool EndObject(SizeType memberCount) { push(FFOJsonTypeEndDict, NULL); return true; }
    bool StartArray() { push(FFOJsonTypeStartArray, NULL); return true; }
    bool EndArray(SizeType elementCount) { push(FFOJsonTypeEndArray, NULL); return true; }
};

extern "C" void gooo(char *json) {
    sEvents = (FFOJsonEvent *)malloc(5000000 * sizeof(*sEvents));
    MyHandler handler;
    Reader reader;
    StringStream ss(json);
    reader.Parse(ss, handler);
}
