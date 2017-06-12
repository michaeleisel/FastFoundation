//
//  NSString_FFOMethods.h
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (FFOMethods)

- (NSArray <NSString *>*)ffo_componentsSeparatedByString:(NSString *)separator;
- (NSString *)ffo_lowercaseString;
- (NSString *)ffo_stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement;
//- (NSString *)ffo_uppercaseString;

@end
