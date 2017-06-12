//
//  FFODateFormatter.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "FFODateFormatter.h"

@implementation FFODateFormatter

- (instancetype)initWithFormatString:(NSString *)formatString
{
    self = [super init];
    if (!self) {
        NSAssert(NO, @"");
        return nil;
    }
    _formatString = formatString;
    return self;
}

- (NSDate *)dateFromString:(NSString *)string
{
    return nil;
}

@end
