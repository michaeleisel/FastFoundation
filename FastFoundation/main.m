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

CFTimeInterval kDiff = 0;
CFTimeInterval kDiff2 = 0;

@interface Asdf : NSObject
+ (void)load;
@end

#include <time.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <err.h>
#include <unistd.h>

static CFTimeInterval processStartTime() {
    size_t len = 4;
    int mib[len];
    struct kinfo_proc kp;

    sysctlnametomib("kern.proc.pid", mib, &len);
    mib[3] = getpid();
    len = sizeof(kp);
    sysctl(mib, 4, &kp, &len, NULL, 0);

    struct timeval startTime = kp.kp_proc.p_un.__p_starttime;
    return startTime.tv_sec + startTime.tv_usec / 1e6;
}

#define NUM_EVENT_SLOTS 1
#define NUM_EVENT_FDS 1

int main(int argc, char * argv[], char **envp) {
    struct timespec tp = {0};
    /*clock_gettime(CLOCK_THREAD_CPUTIME_ID, &tp);
    // [Asdf load];
    uint64_t time = mach_absolute_time();
    // printf("zzz %llu\n\n", time - sMaxTime);
    struct proc_taskallinfo info;
    int res = proc_pidinfo(getpid(), PROC_PIDTASKALLINFO, 0, &info, sizeof(info));
    struct proc_threadinfo tInfo = {0};
    res = proc_pidinfo(getpid(), PROC_PIDTHREADINFO, pthread_self(), &tInfo, sizeof(tInfo));

    printf("tt %lf, %lf\n", ((uint64_t)tp.tv_sec) + tp.tv_nsec / 1e9, [NSDate date].timeIntervalSince1970 - info.pbsd.pbi_start_tvsec);
    NSLog(@"");

    struct timeval ptv = {0};
    CFTimeInterval interval = [[NSDate date] timeIntervalSince1970];*/
    struct timespec time = {0};
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time);

    kDiff = [NSDate date].timeIntervalSince1970 - processStartTime();
    CFTimeInterval postMainStart = CACurrentMediaTime();
	@autoreleasepool {
	    return UIApplicationMain(argc, argv, nil, NSStringFromClass([FFOAppDelegate class]));
	}
}
