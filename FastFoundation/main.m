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

@interface Asdf : NSObject
+ (void)load;
@end

#include <time.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <err.h>
#include <unistd.h>

static void
getstarttime(struct timeval *ptv, CFTimeInterval timeInterval)
{
    static time_t   start; /* We cache this value */
    int             mib[4];
    size_t          len;
    struct kinfo_proc   kp;

    ptv->tv_usec = 0;   /* Not using microseconds at all */

    if (start != 0) {
        ptv->tv_sec = start;
        return;
    }
    ptv->tv_sec = 0;

    len = 4;
    if (sysctlnametomib("kern.proc.pid", mib, &len) != 0) {
        warn("Unable to obtain script start-time: %s",
             "sysctlnametomib");
        return;
    }
    mib[3] = getpid();
    len = sizeof(kp);
    if (sysctl(mib, 4, &kp, &len, NULL, 0) != 0) {
        warn("Unable to obtain script start-time: %s",
             "sysctl");
        return;
    }

    //    start = ptv->tv_sec = kp.ki_start.tv_sec;
    struct timeval starttime = kp.kp_proc.p_un.__p_starttime;
    kDiff = timeInterval - (starttime.tv_sec + starttime.tv_usec / 1e6);
    struct timeval realtime = kp.kp_proc.p_rtime;
    mach_continuous_time();

    /*printf("sleeping for 15 seconds\n");
    sleep(15);

    time_t current_time;
    current_time = time(NULL);
    printf("Process started at      %s\n", ctime(&start));
    printf("Current time after nap  %s\n", ctime(&current_time));*/
}

/* A simple routine to return a string for a set of flags. */
char *flagstring(int flags)
{
    static char ret[512];
    char *or = "";

    ret[0]='\0'; // clear the string.
    if (flags & NOTE_DELETE) {strcat(ret,or);strcat(ret,"NOTE_DELETE");or="|";}
    if (flags & NOTE_WRITE) {strcat(ret,or);strcat(ret,"NOTE_WRITE");or="|";}
    if (flags & NOTE_EXTEND) {strcat(ret,or);strcat(ret,"NOTE_EXTEND");or="|";}
    if (flags & NOTE_ATTRIB) {strcat(ret,or);strcat(ret,"NOTE_ATTRIB");or="|";}
    if (flags & NOTE_LINK) {strcat(ret,or);strcat(ret,"NOTE_LINK");or="|";}
    if (flags & NOTE_RENAME) {strcat(ret,or);strcat(ret,"NOTE_RENAME");or="|";}
    if (flags & NOTE_REVOKE) {strcat(ret,or);strcat(ret,"NOTE_REVOKE");or="|";}

    return ret;
}

#define NUM_EVENT_SLOTS 1
#define NUM_EVENT_FDS 1

int main(int argc, char * argv[], char **envp) {
    NS_VALID_UNTIL_END_OF_SCOPE NSString *strpath = [NSTemporaryDirectory() stringByAppendingString:@"asdf"];
    const char *path = [strpath UTF8String];
    int kq;
    int event_fd;
    struct kevent events_to_monitor[NUM_EVENT_FDS];
    struct kevent event_data[NUM_EVENT_SLOTS];
    void *user_data;
    struct timespec timeout;
    unsigned int vnode_events;

    /* Open a kernel queue. */
    if ((kq = kqueue()) < 0) {
        fprintf(stderr, "Could not open kernel queue.  Error was %s.\n", strerror(errno));
    }

    /*
     Open a file descriptor for the file/directory that you
     want to monitor.
     */
    errno = 0;
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:strpath error:&error];
    assert(error == nil);
    [@"asdf" writeToFile:strpath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    assert(error == nil);
    NSFileHandle *file_fd = [NSFileHandle fileHandleForWritingAtPath:strpath];
    event_fd = open(path, O_EVTONLY);
    int64_t delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
        int z = 2;
        // [file_fd writeData:[@"asdfsdaf" dataUsingEncoding:NSUTF8StringEncoding]];
        ssize_t written = write(file_fd.fileDescriptor, &z, sizeof(z));
        assert(written > 0);
    });
    if (event_fd <=0) {
        fprintf(stderr, "The file %s could not be opened for monitoring.  Error was %s.\n", path, strerror(errno));
        exit(-1);
    }

    /*
     The address in user_data will be copied into a field in the
     event.  If you are monitoring multiple files, you could,
     for example, pass in different data structure for each file.
     For this example, the path string is used.
     */
    user_data = path;

    /* Set the timeout to wake us every half second. */
    timeout.tv_sec = 0;        // 0 seconds
    timeout.tv_nsec = 500000000;    // 500 milliseconds

    /* Set up a list of events to monitor. */
    vnode_events = NOTE_DELETE |  NOTE_WRITE | NOTE_EXTEND |                            NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME | NOTE_REVOKE;
    EV_SET( &events_to_monitor[0], event_fd, EVFILT_VNODE, EV_ADD | EV_CLEAR, vnode_events, 0, user_data);

    /* Handle events. */
    int num_files = 1;
    int continue_loop = 40; /* Monitor for twenty seconds. */
    while (--continue_loop) {
        int event_count = kevent(kq, events_to_monitor, NUM_EVENT_SLOTS, event_data, num_files, &timeout);
        if ((event_count < 0) || (event_data[0].flags == EV_ERROR)) {
            /* An error occurred. */
            fprintf(stderr, "An error occurred (event count %d).  The error was %s.\n", event_count, strerror(errno));
            break;
        }
        if (event_count) {
            printf("Event %" PRIdPTR " occurred.  Filter %d, flags %d, filter flags %s, filter data %" PRIdPTR ", path %s\n",
                   event_data[0].ident,
                   event_data[0].filter,
                   event_data[0].flags,
                   flagstring(event_data[0].fflags),
                   event_data[0].data,
                   (char *)event_data[0].udata);
        } else {
            printf("No event.\n");
        }

        /* Reset the timeout.  In case of a signal interrruption, the
         values may change. */
        timeout.tv_sec = 0;        // 0 seconds
        timeout.tv_nsec = 500000000;    // 500 milliseconds
    }
    close(event_fd);
    return 0;
}

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

    /*struct timeval ptv = {0};
    CFTimeInterval interval = [[NSDate date] timeIntervalSince1970];
    getstarttime(&ptv, interval);
	@autoreleasepool {
	    return UIApplicationMain(argc, argv, nil, NSStringFromClass([FFOAppDelegate class]));
	}
}
*/
