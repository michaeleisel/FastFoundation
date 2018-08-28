//
//  FFODateFormatter.h
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFODateFormatter : NSDateFormatter // todo: change

// todo: relative date formatting

/*- (instancetype)initWithFormatString:(NSString *)formatString;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;*/

// remove init with coder? how to deal with that?

// todo: thread safety

@property (strong, atomic) NSString *formatString;
@property (strong, nonatomic, readonly) NSCalendar *calendar; // This is read-only because this only supports the gregorian calendar

/*@property (null_resettable, copy) NSString *dateFormat;
@property NSDateFormatterStyle dateStyle;
@property NSDateFormatterStyle timeStyle;
@property (null_resettable, copy) NSLocale *locale;
@property BOOL generatesCalendarDates;
@property NSDateFormatterBehavior formatterBehavior;
@property (null_resettable, copy) NSTimeZone *timeZone;
@property (null_resettable, copy) NSCalendar *calendar;
@property (getter=isLenient) BOOL lenient;
@property (nullable, copy) NSDate *twoDigitStartDate;
@property (nullable, copy) NSDate *defaultDate;
@property (null_resettable, copy) NSArray<NSString *> *eraSymbols;
@property (null_resettable, copy) NSArray<NSString *> *monthSymbols;
@property (null_resettable, copy) NSArray<NSString *> *shortMonthSymbols;
@property (null_resettable, copy) NSArray<NSString *> *weekdaySymbols;
@property (null_resettable, copy) NSArray<NSString *> *shortWeekdaySymbols;
@property (null_resettable, copy) NSString *AMSymbol;
@property (null_resettable, copy) NSString *PMSymbol;
@property (null_resettable, copy) NSArray<NSString *> *longEraSymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *veryShortMonthSymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *standaloneMonthSymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *shortStandaloneMonthSymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *veryShortStandaloneMonthSymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *veryShortWeekdaySymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *standaloneWeekdaySymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *shortStandaloneWeekdaySymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *veryShortStandaloneWeekdaySymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *quarterSymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *shortQuarterSymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *standaloneQuarterSymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (null_resettable, copy) NSArray<NSString *> *shortStandaloneQuarterSymbols API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property (nullable, copy) NSDate *gregorianStartDate API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@property BOOL doesRelativeDateFormatting API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));*/

@end
