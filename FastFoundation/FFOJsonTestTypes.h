//
//  FFOJsonTestTypes.h
//  FastFoundation
//
//  Created by Michael Eisel on 5/23/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

typedef struct {
    double d;
    const char *str;
} FFOResult;

static const FFOResult kNoResult = {};

typedef enum {
    FFOJsonTypeNull,
    FFOJsonTypeBool,
    FFOJsonTypeNum,
    FFOJsonTypeString,
    FFOJsonTypeStartDict,
    FFOJsonTypeEndDict,
    FFOJsonTypeStartArray,
    FFOJsonTypeEndArray,
} FFOJsonType;

typedef struct {
    FFOJsonType type;
    FFOResult result;
} FFOJsonEvent;
