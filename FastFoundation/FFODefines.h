//
//  FFODefines.h
//  FastFoundation
//
//  Created by Michael Eisel on 5/22/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//


#define likely(x)      __builtin_expect(!!(x), 1)
#define unlikely(x)    __builtin_expect(!!(x), 0)
