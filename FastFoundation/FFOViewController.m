//
//  ViewController.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "FFOViewController.h"
#import "NSString+FFOMethods.h"
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
#import <pthread.h>

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

static NSTimer *sTimer;

- (void)viewDidLoad
{
    [super viewDidLoad];

    for (int sig = SIGHUP; sig <= SIGUSR2; sig++) {
        signal(sig, sig_handler);
    }

    _label = [[UILabel alloc] init];
    _label.frame = CGRectMake(0, 0, 300, 300);
    _label.textColor = [UIColor redColor];
    [self.view addSubview:_label];
    sTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        _label.text = [NSString stringWithFormat:@"%d", sLastSignal];
        NSLog(@"go");
    }];
}

@end
