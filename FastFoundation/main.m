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

// extern uint64_t sMaxTime;

@interface Asdf : NSObject
+ (void)load;
@end

int main(int argc, char * argv[], char **envp) {
    /*struct timespec tp = {0};
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &tp);
    // [Asdf load];
    uint64_t time = mach_absolute_time();
    // printf("zzz %llu\n\n", time - sMaxTime);
    struct proc_taskallinfo info;
    int res = proc_pidinfo(getpid(), PROC_PIDTASKALLINFO, 0, &info, sizeof(info));
    struct proc_threadinfo tInfo = {0};
    res = proc_pidinfo(getpid(), PROC_PIDTHREADINFO, pthread_self(), &tInfo, sizeof(tInfo));

    printf("tt %lf, %lf\n", ((uint64_t)tp.tv_sec) + tp.tv_nsec / 1e9, [NSDate date].timeIntervalSince1970 - info.pbsd.pbi_start_tvsec);
    NSLog(@"");*/

	@autoreleasepool {
	    return UIApplicationMain(argc, argv, nil, NSStringFromClass([FFOAppDelegate class]));
	}
}
