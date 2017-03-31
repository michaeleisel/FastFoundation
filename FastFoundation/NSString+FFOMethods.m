//
//  NSString_FFOMethods.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "NSString+FFOMethods.h"
#import <pthread.h>

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
		CFStringRef component = CFStringCreateWithCString(kCFAllocatorDefault, remainingStr, kCFStringEncodingUTF8);
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
	return CFBridgingRelease(CFStringCreateWithCString(kCFAllocatorDefault, buffer->string, kCFStringEncodingUTF8));
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
