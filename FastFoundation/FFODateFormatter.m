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

/*#define UNSUPPORTED_LOCALE_METHOD \
@throw [NSException exceptionWithName:@"FFODateFormatter exception" reason:@"FFODateFormatter only supports en_us, so methods related to locales are not supported" userInfo:nil]*/

@implementation FFODateFormatter {
    const char *_format;
}

@dynamic calendar;

- (instancetype)initWithFormatString:(NSString *)formatString
{
    self = [super init];
    if (!self) {
        return nil;
    }
    _formatString = formatString; // This is just to retain it so we can use the inner buffer
    _format = formatString.UTF8String;
    NSAssert(_format, @"The string passed in must be well-formed unicode");
    return self;
}

- (NSDate *)dateFromString:(NSString *)string
{
    const char *buf = string.UTF8String;
    NSAssert(buf, @"The string passed in must be well-formed unicode");
    struct tm components;
    strptime(buf, _format, &components);
    time_t time = mktime(&components);
    return CFBridgingRelease(CFDateCreate(kCFAllocatorDefault, time));
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
