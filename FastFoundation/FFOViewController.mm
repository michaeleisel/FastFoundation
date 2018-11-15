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

static void func(void) {
    /*dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, <#dispatchQueue#>);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, <#intervalInSeconds#> * NSEC_PER_SEC, <#leewayInSeconds#> * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        <#code to be executed when timer fires#>
    });
    dispatch_resume(timer);*/
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    func();
}

@end
