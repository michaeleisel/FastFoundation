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

- (instancetype)initWithFormatString:(NSString *)formatString;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (strong, nonatomic, readonly) NSString *formatString;
@property (strong, nonatomic, readonly) NSCalendar *calendar; // This is read-only because this only supports the gregorian calendar

@end
