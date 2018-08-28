//
//  FFOThreadLocalMemory.m
//  FastFoundation
//
//  Created by Michael Eisel on 8/28/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#import "FFOThreadLocalMemory.h"

static const NSInteger kFFOBufferCount = 5;

typedef struct {
    BOOL reserved;
    char *buffer[kFFOBufferSize];
} FFOBuffer;

static __thread FFOBuffer tBuffers[kFFOBufferCount];

void *FFOReserveBuffer(void) {
    for (NSInteger i = 0; i < kFFOBufferCount; i++) {
        if (!tBuffers[i].reserved) {
            return tBuffers[i].buffer;
        }
    }

    return NULL;
}

void FFOUnreserveBuffer(void *buffer) {
    for (NSInteger i = 0; i < kFFOBufferCount; i++) {
        if (tBuffers[i].buffer == buffer) {
            tBuffers[i].reserved = NO;
            return;
        }
    }

    NSCAssert(NO, @"Invalid buffer given to FFOFreeBuffer");
}
