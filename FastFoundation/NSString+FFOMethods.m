//
//  NSString_FFOMethods.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "NSString+FFOMethods.h"
#import "jemalloc.h"
#import <pthread.h>
#import "FFOJemallocAllocator.h"

typedef struct {
	char *string;
	NSInteger stringLength;
	NSInteger stringCapacity;
	CFTypeRef *array;
	NSInteger arrayLength;
	NSInteger arrayCapacity;
} FFOBuffer;

static const NSInteger kFFOBufferCount = 40;
static const NSInteger kFFOBufferStringCapacity = 2000;
static const NSInteger kFFOBufferArrayCapacity = 100;

static FFOBuffer sBuffers[kFFOBufferCount];

@implementation NSString (FFOMethods)

// length does not include nil terminator
CFStringRef FFOStringFromCString(const char *cString, NSInteger length) {
    char *newCString = je_malloc(length + 1);
    memcpy(newCString, cString, length + 1);
    return CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, newCString, kCFStringEncodingUTF8, FFOJemallocAllocator());
}

// todo: make certain strings valid until end of scope
- (NSArray <NSString *>*)ffo_componentsSeparatedByString:(NSString *)separator
{
	FFOBuffer *buffer = FFOGetBuffer();
	const char *originalStr = FFOCStringFromString(self);
	const char *sepStr = FFOCStringFromString(separator);
	if (!originalStr || !sepStr) {
		NSCAssert(NO, @"");
    	return nil;
	}
	NSInteger originalStrLength = strlen(originalStr);
	NSInteger sepLength = strlen(sepStr);
	memcpy(buffer->string, originalStr, originalStrLength);

	char *nextMatch = NULL;
	char *remainingStr = buffer->string;
	do {
		nextMatch = (char *)(strstr(remainingStr, sepStr) ?: &buffer->string[originalStrLength]);
		char prevValue = *nextMatch;
		*nextMatch = '\0';
        CFStringRef component = FFOStringFromCString(remainingStr, strlen(remainingStr));
		*nextMatch = prevValue;
		buffer->array[buffer->arrayLength++] = component;
		remainingStr = nextMatch + sepLength;
	} while (remainingStr < &buffer->string[originalStrLength]);
	NSArray <NSString *>*components = CFBridgingRelease(CFArrayCreate(kCFAllocatorDefault, buffer->array, buffer->arrayLength, NULL));
	buffer->stringLength = 0;
	buffer->arrayLength = 0;
	return components;
}

- (NSString *)ffo_lowercaseString
{
	const char *str = FFOCStringFromString(self);
	NSInteger strLength = strlen(str);
	FFOBuffer *buffer = FFOGetBuffer();
	memcpy(buffer->string, str, strLength);
	BOOL hasUppercaseChars = NO;
	for (NSInteger i = 0; i < strLength; i++) {
		char c = buffer->string[i];
		// If there are non-ASCII characters, give up
		if (c & 0x80) {
			return [self lowercaseString];
		}
		if ('A' <= c && c <= 'Z') {
			buffer->string[i] = tolower(c);
			hasUppercaseChars = YES;
		}
	}
	if (!hasUppercaseChars) {
		return [self copy];
	}
    buffer->string[strLength] = '\0';
	return CFBridgingRelease(CFStringCreateWithCString(kCFAllocatorDefault, buffer->string, kCFStringEncodingUTF8));
}

- (NSString *)ffo_stringByReplacingOccurrencesOfString:(NSString *)targetString withString:(NSString *)replacementString
{
    const char *target = FFOCStringFromString(targetString);
    const char *replacement = FFOCStringFromString(replacementString);
    const char *chars = FFOCStringFromString(self);
    FFOBuffer *buffer = FFOGetBuffer();
    if (!buffer || !target || !replacement || !chars) {
        return [self stringByReplacingOccurrencesOfString:targetString withString:replacementString];
    }
    const char *remainingStr = chars;
    const char *end = chars + strlen(chars);
    NSInteger targetLength = strlen(target);
    NSInteger replacementLength = strlen(replacement);
    do {
        const char *nextMatch = strstr(remainingStr, target) ?: end;
        FFOCopyBuffer(buffer, remainingStr, nextMatch - remainingStr);
        if (nextMatch < end) {
            FFOCopyBuffer(buffer, replacement, replacementLength);
        }
        remainingStr = nextMatch + targetLength;
    } while (remainingStr < end);
    buffer->string[buffer->stringLength] = '\0';
    // Cleanup
    buffer->stringLength = 0;
    return CFBridgingRelease(CFStringCreateWithCString(kCFAllocatorDefault, buffer->string, kCFStringEncodingUTF8));
}

static void FFOCopyBuffer(FFOBuffer *buffer, const char *new, NSInteger newLength)
{
    memcpy(buffer->string + buffer->stringLength, new, newLength);
    buffer->stringLength += newLength;
}

static const char *FFOCStringFromString(NSString *string)
{
	// todo: copy characters into a buffer instead of calling -UTF8String
	return CFStringGetCStringPtr((CFStringRef)string, kCFStringEncodingUTF8) ?: [string UTF8String];
}

static FFOBuffer *FFOGetBuffer(void)
{
	NSInteger index = 0;//pthread_mach_thread_np(pthread_self());
	if (index < kFFOBufferCount) {
		FFOBuffer *buffer = &sBuffers[index];
		if (buffer->string == NULL) {
			buffer->string = malloc(kFFOBufferStringCapacity);
			buffer->stringCapacity = kFFOBufferStringCapacity;
			buffer->array = malloc(kFFOBufferArrayCapacity);
			buffer->arrayCapacity = kFFOBufferArrayCapacity;
		}
		return buffer;
	}

	NSCAssert(NO, @"");
	return NULL;
}

@end
