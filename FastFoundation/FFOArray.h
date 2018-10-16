//
//  FFOArray.h
//  FastFoundation
//
//  Created by Michael Eisel on 5/22/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#import "FFODefines.h"

typedef struct {
    uint32_t *elements;
    NSInteger length;
    NSInteger capacity;
} FFOArray;

static FFOArray *FFOArrayWithCapacity(NSInteger capacity) {
    if (capacity == 0) {
        capacity++;
    }
    FFOArray *array = malloc(sizeof(FFOArray));
    array->elements = malloc(sizeof(array->elements[0]) * capacity);
    array->length = 0;
    array->capacity = capacity;
    return array;
}

static inline void FFOGrowArray(FFOArray *array, NSInteger capacity) {
    // Grow it to the smallest power of 2 that is greater than or equal to capacity
    while (array->capacity < capacity) {
        array->capacity *= 2;
    }
    array->elements = realloc(array->elements, sizeof(array->elements[0]) * array->capacity);
}

static inline void FFOPushToArray(FFOArray *array, uint32_t element) {
    if (unlikely(array->length >= array->capacity)) {
        FFOGrowArray(array, array->capacity * 2);
    }
    array->elements[array->length++] = element;
}

static BOOL FFOArraysAreEqual(FFOArray *a1, FFOArray *a2) {
    return a1->length == a2->length && !memcmp(a1->elements, a2->elements, sizeof(*a1->elements) * a1->length);
}

static void FFOFreeArray(FFOArray *array) {
    free(array->elements);
    free(array);
}
