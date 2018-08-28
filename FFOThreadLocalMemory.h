//
//  FFOThreadLocalMemory.h
//  FastFoundation
//
//  Created by Michael Eisel on 8/28/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

#import <Foundation/Foundation.h>

static const NSInteger kFFOBufferSize = 2 * 1024;

void *FFOReserveBuffer(void);
void FFOUnreserveBuffer(void *buffer);
