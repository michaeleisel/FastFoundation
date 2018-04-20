//
//  NSArrayFFOMethods.m
//  FastFoundation
//
//  Created by Michael Eisel on 6/11/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "NSArrayFFOMethods.h"

static char sBuffer[1000];

static Class sNSStringClass;

@implementation NSArray (FFOMethods)

- (NSString *)ffo_componentsJoinedByString:(NSString *)joiner
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sNSStringClass = [NSString class];
    });
    NSInteger objectsDone = 0;
    NSInteger count = self.count;
    NSInteger i = 0;
    const char *joinerStr = CFStringGetCStringPtr((__bridge CFStringRef)joiner, kCFStringEncodingUTF8); // joiner.UTF8String;
    NSInteger joinerLen = strlen(joinerStr);
    for (id object in self) {
        const char *str;
        if ([object isKindOfClass:sNSStringClass]) {
            str = ((NSString *)object).UTF8String;
        } else {
            str = [object description].UTF8String;
        }
        if (!str) {
            return [self componentsJoinedByString:joiner];
        }
        NSInteger strLength = strlen(str);
        memcpy(&(sBuffer[i]), str, strLength);
        i += strLength;
        objectsDone++;
        if (objectsDone < count) {
            memcpy(&(sBuffer[i]), joinerStr, joinerLen);
            i += joinerLen;
        }
    }
    sBuffer[i] = '\0';
    return CFBridgingRelease(CFStringCreateWithCString(kCFAllocatorDefault, sBuffer, kCFStringEncodingUTF8));
}

- (void)ffo_shuffledArray
{
    /*NSUInteger count = self.count;
    if (count > (sizeof(buffer) / sizeof(*buffer))) {
        return [self shuffledArray];
    }
    arc4random_uniform();*/
}

@end
