//
//  FFOJsonTestTypes.h
//  FastFoundation
//
//  Created by Michael Eisel on 5/23/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

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
    void *ptr;
} FFOJsonEvent;
