//
//  ViewController.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "FFOViewController.h"
#import "libproc.h"
/*#import "NSString+FFOMethods.h"
#import "pcg_basic.h"
#import "NSArrayFFOMethods.h"
#import "rust_bindings.h"
#import "FFOArray.h"
#import "FFOString.h"
#import "ConvertUTF.h"
#import "FFORapidJsonTester.h"
#import "FFOJsonTester.h"
#import "FFOJsonParser.h"
#import "FFODateFormatter.h"
#import "FFOEnvironment.h"
#import "jemalloc.h"
#import "FFOJemallocAllocator.h"
#import <malloc/malloc.h>
#import <execinfo.h>
#import <mach-o/dyld.h>
#import "FFOEnabler.h"
#import <sys/utsname.h>
#import <sys/event.h>
#import <sys/resource.h>
#import "libproc.h"
#import <pthread.h>*/

@interface FFOViewController ()

@end

@implementation FFOViewController {
    UINavigationController *_navController;
    UIViewController *_childController;
    UILabel *_label;
}

static int sFd = -1;
static int sLastSignal = -1;

void sig_handler(int sig) {
    sLastSignal = sig;
    // write(sFd, &sig, sizeof(sig));
}

void *je_wrap_malloc(size_t size);

extern void kdbg_dump_trace_to_file(const char *);

static NSTimer *sTimer;

static void *wait_for_pressure_event(void *s);

- (void)viewDidLoad
{
    [super viewDidLoad];

    wait_for_pressure_event(NULL);
}

static void *wait_for_pressure_event(void *s) {
    int kq;
    int res;
    struct kevent event, mevent;
    char errMsg[100 + 1];

    kq = kqueue();

    EV_SET(&mevent, 0, EVFILT_VM, EV_ADD, NOTE_VM_PRESSURE, 0, 0);

    res = kevent(kq, &mevent, 1, NULL, 0, NULL);
    if (res != 0) {
        abort();
        /*printf("\t\tKevent registration failed - returning: %d!\n", res);*/
        //snprintf(errMsg, ERR_BUF_LEN, "Kevent registration failed - returning: %d!",res);
        // printTestResult(__func__, false, errMsg);
        // cleanup_and_exit(-1);
    }

    while (1) {
        memset(&event, 0, sizeof(struct kevent));
        res = kevent(kq, NULL, 0, &event, 1, NULL);
        // g_shared->pressure_event_fired = 1;
    }
}

@end
