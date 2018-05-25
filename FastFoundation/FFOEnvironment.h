//
//  FFOEnvironment.h
//  FastFoundation
//
//  Created by Michael Eisel on 5/25/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

static __attribute__((always_inline)) bool FFOIsDebug() {
#ifdef DEBUG
    return 1;
#else
    return 0;
#endif
}

