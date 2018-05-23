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
    // Hack to do one malloc to allocate for two pointers
    FFOArray *array = malloc(sizeof(FFOArray));
    array->elements = malloc(sizeof(array->elements[0]) * capacity);
    array->length = 0;
    array->capacity = capacity;
    return array;
}

static inline void FFOGrowArray(FFOArray *array, NSInteger capacity) {
    // Grow it to the smallest power of 2 that is greater than or equal to capacity
    NSCAssert(array->capacity != 0, @"only designed for non-zero capacity");
    while (array->capacity < capacity) {
        array->capacity *= 2;
    }
    uint32_t *elements = array->elements;
    NSInteger size = sizeof(array->elements[0]) * array->capacity;
    array->elements = malloc(size);
    memcpy(array->elements, elements, size);
    free(elements);
}

static inline void FFOPushToArray(FFOArray *array, int32_t element) {
    if (unlikely(array->length >= array->capacity)) {
        FFOGrowArray(array, array->capacity * 2);
    }
    array->elements[array->length++] = element;
}
