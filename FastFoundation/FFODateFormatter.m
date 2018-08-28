//
//  FFODateFormatter.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "FFODateFormatter.h"
#import <pthread.h>
// #import "rust_bindings.h"
#import "jemalloc.h"
#import "FFOThreadLocalMemory.h"

struct FFODateComponent {
    NSCalendarUnit unit;
    NSInteger minLength;
};

/*#define UNSUPPORTED_LOCALE_METHOD \
@throw [NSException exceptionWithName:@"FFODateFormatter exception" reason:@"FFODateFormatter only supports en_us, so methods related to locales are not supported" userInfo:nil]*/

@implementation FFODateFormatter {
    NSString *_dateFormat;
    char *_format;
    pthread_mutex_t _lock;
}

@dynamic calendar;

@synthesize dateFormat = _dateFormat;

// const char *FFOCStringCopyFromString(NSString )

-(id)init
{
    self = [super init];
    if (self) {
        _lock = (pthread_mutex_t)PTHREAD_MUTEX_INITIALIZER;
        _format = NULL;
    }
    return self;
}

#define FFO_SYNCHRONIZE(...) \

- (NSString *)dateFormat
{
    __block NSString *dateFormat = nil;

    pthread_mutex_lock(&_lock);
    ({
        dateFormat = _dateFormat;
    });
    pthread_mutex_unlock(&_lock);

    return dateFormat;
}

- (void)setDateFormat:(NSString *)dateFormat
{
    pthread_mutex_lock(&_lock);
    ({
        if (_format) {
            free(_format);
        }

        const char *format = dateFormat.UTF8String;
        NSInteger lengthPlusTerminator = strlen(format) + 1;
        _format = je_malloc(lengthPlusTerminator);
        memcpy(_format, format, lengthPlusTerminator);

        _dateFormat = [dateFormat retain];

        NSAssert(_format, @"The string passed in must be well-formed unicode");
    });
    pthread_mutex_unlock(&_lock);
}

- (void)dealloc
{
    if (_format) {
        je_free(_format);
    }
    [_dateFormat autorelease];
    // If the mutex is locked at this point, then this is undefined behavior, but that shouldn't be true at this point
    pthread_mutex_destroy(&_lock);

    [super dealloc];
}

- (NSDate *)dateFromString:(NSString *)string
{
    CFDateRef date = NULL;

    pthread_mutex_lock(&_lock);
    ({
        const char *buf = string.UTF8String;
        NSAssert(buf, @"The string passed in must be well-formed unicode");
        struct tm components;
        strptime(buf, _format, &components);
        time_t time = mktime(&components);
        // todo: error handling
        date = CFDateCreate(kCFAllocatorDefault, time);
    });
    pthread_mutex_unlock(&_lock);

    return CFBridgingRelease(date);
}

static inline void FFOFree(void *buffer, BOOL usesMalloc) {
    if (usesMalloc) {
        je_free(buffer);
    } else {
        FFOUnreserveBuffer(buffer);
    }
}

/*static inline void FFOGrowBufferNoCopy(void *buffer, NSInteger size, BOOL usesMalloc) {
    FFOFree(buffer, usesMalloc);
    NSInteger newSize = size * 2;
    je_malloc(newSize);
}*/

- (NSString *)stringFromDate:(NSDate *)date
{
    void *buffer = FFOReserveBuffer();
    NSInteger size = kFFOBufferSize;
    BOOL usesMalloc = buffer == NULL;
    if (usesMalloc) {
        buffer = je_malloc(size);
    }

    struct tm timeinfo = {0};
    NSTimeInterval time = date.timeIntervalSince1970;
    time_t timeWithoutMillis = (time_t)time;
    localtime_r(&timeWithoutMillis, &timeinfo);
    NSInteger formatLength = 0;
    while (YES) {
        const char *posixFormat = "%Y-%m-%dT%H:%M:%S.000Z";// "%Y-%m-%dT%H:%M:%S.000";
        NSInteger bytesWritten = strftime(buffer, size, posixFormat, &timeinfo);
        if (bytesWritten > 0) { // This is almost always true, since the buffer is large to begin with
            break;
        }
        if (formatLength == 0) {
            formatLength = strlen(_format);
        }
        // If the size seems way larger than what the format string could generate, assume that some other issue has occurred, and that we shouldn't simply keep growing the buffer
        NSAssert(size < formatLength * 10, @"An error occurred, perhaps the format string is malformed?");
        FFOFree(buffer, usesMalloc);
        size *= 2;
        buffer = je_malloc(size);
        usesMalloc = YES;
    }

    CFStringRef string = CFStringCreateWithCString(kCFAllocatorDefault, buffer, kCFStringEncodingUTF8);
    FFOFree(buffer, usesMalloc);
    return CFBridgingRelease(string);
}

- (NSCalendar *)calendar
{
    return [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
}

/*+ (NSString *)localizedStringFromDate:(NSDate *)date dateStyle:(NSDateFormatterStyle)dstyle timeStyle:(NSDateFormatterStyle)tstyle
{
    // todo
}

- (BOOL)getObjectValue:(out id  _Nullable *)obj forString:(NSString *)string range:(inout NSRange *)rangep error:(out NSError * _Nullable *)error
{
    // todo
}*/

@end
