//
//  FFODateFormatter.h
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFODateFormatter : NSObject

- (instancetype)initWithFormatString:(NSString *)formatString;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (strong, nonatomic, readonly) NSString *formatString;

@end
