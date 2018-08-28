//
//  FFOJsonParser.h
//  FastFoundation
//
//  Created by Michael Eisel on 5/23/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFOArray.h"

typedef void (*FFOStringCallback)(char *);
typedef void (*FFONumberCallback)(double);
typedef void (*FFOBoolCallback)(bool);
typedef void (*FFONotificationCallback)();

typedef struct {
    FFOStringCallback stringCallback;
    FFONumberCallback numberCallback;
    FFONotificationCallback arrayStartCallback;
    FFONotificationCallback arrayEndCallback;
    FFONotificationCallback dictionaryStartCallback;
    FFONotificationCallback dictionaryEndCallback;
    FFONotificationCallback nullCallback;
    FFOBoolCallback boolCallback;
} FFOCallbacks;


void FFORunTests();
void FFOParseJson(char *string, uint32_t length, FFOCallbacks *callbacks);
void FFOGatherCharIdxs(const char *string, uint32_t length, FFOArray **quoteIdxsPtr, FFOArray **slashIdxsPtr);
