//
//  main.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FFOAppDelegate.h"
#import <mach/mach_time.h>
#import "libproc.h"
#import <pthread.h>
#import "procInfo2.h"

// extern uint64_t sMaxTime;

@interface Asdf : NSObject
+ (void)load;
@end

int main(int argc, char * argv[], char **envp) {
    ProcInfo *p = [[ProcInfo alloc] init:NO];
    NSArray *a = [p currentProcesses];
    /*sleep(1);
    struct rusage rus;
    int res = getrusage(RUSAGE_SELF, &rus);
    assert(res == 0);
    clock_t c = clock();*/
	@autoreleasepool {
	    return UIApplicationMain(argc, argv, nil, NSStringFromClass([FFOAppDelegate class]));
	}
}
