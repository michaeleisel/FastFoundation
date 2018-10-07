//
//  FFOJemallocAllocator.m
//  FastFoundation
//
//  Created by Michael Eisel on 8/28/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#import "FFOJemallocAllocator.h"
#import "jemalloc.h"

static CFAllocatorRef sJemallocAllocator;

// static NSMutableSet *sSet;

void *FFOContextMalloc(CFIndex allocSize, CFOptionFlags hint, void *info) {
    return je_malloc(allocSize);
}

void * FFOContextRealloc(void *ptr, CFIndex newsize, CFOptionFlags hint, void *info) {
    return je_realloc(ptr, newsize);
}

void FFOContextDealloc(void *ptr, void *info) {
    je_free(ptr);
}

CFIndex FFOContextPreferredSize(CFIndex size, CFOptionFlags hint, void *info) {
    // Round up to the next multiple of 16 to copy what jemalloc does it allocates, since it's 16-byte aligned
    NSInteger remainder = size & 0xFF; // remainder = size % 16
    if (remainder == 0) {
        return size;
    }
    return size + 16 - remainder;
}

static CFAllocatorContext sJemallocContext = {
    .version = 0,
    .info = NULL,
    .retain = NULL,
    .release = NULL,
    .copyDescription = NULL,
    .allocate = FFOContextMalloc,
    .reallocate = FFOContextRealloc,
    .deallocate = FFOContextDealloc,
    .preferredSize = FFOContextPreferredSize,
};

__used CFAllocatorRef FFOJemallocAllocator() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sJemallocAllocator = CFAllocatorCreate(kCFAllocatorDefault, &sJemallocContext);
        // sSet = [NSMutableSet set];
    });
    return sJemallocAllocator;
}
