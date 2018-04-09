//
//  FFODateFormatter.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "FFODateFormatter.h"

struct FFODateComponent {
    NSCalendarUnit unit;
    NSInteger minLength;
};

@implementation FFODateFormatter {
    const char *_format;
}

- (instancetype)initWithFormatString:(NSString *)formatString
{
    self = [super init];
    if (!self) {
        return nil;
    }
    _formatString = formatString; // This is just to retain it so we can use the inner buffer
    _format = formatString.UTF8String;
    NSAssert(_format, @"must be convertible to a UTF-8 string");
    return self;
}

- (NSDate *)dateFromString:(NSString *)string
{
    const char *buf = string.UTF8String;
    NSAssert(buf, @"must be convertible to a UTF-8 string");
    struct tm components;
    strptime(buf, _format, &components);
    time_t time = mktime(&components);
    return CFBridgingRelease(CFDateCreate(kCFAllocatorDefault, time));
}

@end
