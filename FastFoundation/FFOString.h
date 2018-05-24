//
//  FFOString.h
//  FastFoundation
//
//  Created by Michael Eisel on 5/23/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#import "FFODefines.h"

typedef struct {
    char *chars;
    uint32_t length;
    uint32_t capacity;
} FFOString;

static FFOString *FFOStringWithCapacity(uint32_t capacity) {
    if (capacity == 0) {
        capacity++;
    }
    // Hack to do one malloc to allocate for two pointers
    FFOString *string = malloc(sizeof(FFOString));
    string->chars = malloc(sizeof(string->chars[0]) * capacity);
    string->length = 0;
    string->capacity = capacity;
    return string;
}

static inline void FFOGrowString(FFOString *string, uint32_t capacity) {
    while (string->capacity < capacity) {
        string->capacity *= 2;
    }
    char *chars = string->chars;
    string->chars = malloc(sizeof(string->chars[0]) * string->capacity);
    memcpy(string->chars, chars, sizeof(string->chars[0]) * string->length);
    free(chars);
}

static inline void FFOPushToString(FFOString *string, char *chars, uint32_t length) {
    uint32_t newCapacity = string->length + length;
    if (unlikely(newCapacity >= string->capacity)) {
        FFOGrowString(string, newCapacity);
    }
    memcpy(string->chars + string->length, chars, length * sizeof(*chars));
    string->length += length;
}

static BOOL FFOStringsAreEqual(FFOString *a1, FFOString *a2) {
    return a1->length == a2->length && !memcmp(a1->chars, a2->chars, sizeof(*a1->chars) * a1->length);
}

static void FFOFreeString(FFOString *string) {
    free(string->chars);
    free(string);
}
