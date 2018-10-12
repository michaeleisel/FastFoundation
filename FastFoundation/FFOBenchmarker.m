//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "FFOBenchmarker.h"
#import <QuartzCore/QuartzCore.h>
#import <execinfo.h>
#import <pthread.h>


#define BENCH(name, ...) \
({ \
printf("%s\n", name); \
sHasGone = NO; \
sShouldStop = NO; \
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), queue, ^(void){ \
sShouldStop = YES; \
}); \
CFTimeInterval startTime, endTime; \
NSInteger count = 0; \
@autoreleasepool { \
startTime = CACurrentMediaTime(); \
while (!sShouldStop) { \
sResult += (int)__VA_ARGS__; \
count++; \
sHasGone = YES; \
} \
endTime = CACurrentMediaTime(); \
usleep(500000); \
} \
printf("%.2e per second\n", count / (endTime - startTime)); \
sShouldStop = NO; \
})

BOOL sHasGone = NO;
BOOL sShouldStop = NO;
volatile NSInteger sResult = 0;
extern __attribute__((noinline)) int64_t process_chars(char *str, int64_t length, void *dest);

@implementation FFOBenchmarker {
    NSThread *_trackerThread;
    pthread_t _mainThread;
}

void FFOTestProcessChars(char *string, char *dest, NSInteger length) {
    process_chars(string, length, dest);
    for (NSInteger i = 0; i < length; i++) {
        BOOL isQuote = !!((dest[i / 8] >> (7 - i % 8)) & 1);
        if (isQuote) {
            assert(string[i] == '"');
        } else {
            assert(string[i] != '"');
        }
    }
}

// static const NSInteger kMaxCallstackSize = 4;
// static const NSInteger kCallstacksSize = 5000;
#define CALLSTACKS_SIZE 5000
#define CALLSTACK_SIZE 5

static void *sCallstacks[CALLSTACKS_SIZE][CALLSTACK_SIZE];
static NSInteger sCallstackCount = 0;

__used static void FFOPrintStacks() {
    for (NSInteger i = 0; i < sCallstackCount; i++) {
        char **syms = backtrace_symbols(sCallstacks[i], CALLSTACK_SIZE);
        for (NSInteger j = 0; j < CALLSTACK_SIZE; j++) {
            // printf("(%s, %p, %ld)", syms[i], sCallstacks[i][j], sCallstacks[i][j] - (void*)process_chars);
            printf("%s", syms[j]);
            if (j < CALLSTACK_SIZE - 1) {
                printf("\n");
            }
        }
        printf("\n\n\n");
        free(syms);
    }
    printf("%p\n", process_chars);
}

static void _callstack_signal_handler(int signr, siginfo_t *info, void *secret) {
    backtrace(sCallstacks[sCallstackCount], CALLSTACK_SIZE);
    sCallstackCount++;
    if (sCallstackCount >= CALLSTACKS_SIZE) {
        sCallstackCount = 0;
    }
}

-(void)_beginMonitoringStacks
{
    struct sigaction sa;
    sigfillset(&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = _callstack_signal_handler;
    sigaction(SIGPROF, &sa, NULL);

    _mainThread = pthread_self();

    _trackerThread = [[NSThread alloc] initWithTarget:self selector:@selector(_trackerLoop) object:nil];
    _trackerThread.threadPriority = 1.0;
    [_trackerThread start];
}

- (void)_trackerLoop
{
    while (YES) {
        usleep(10000);
        pthread_kill(_mainThread, SIGPROF);
    }
}

- (void)performBenchmarks
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    char str[5000];
    char dest[sizeof(str) / 8] = {0};
    NSInteger alignment = 16;
    NSInteger mod = (NSUInteger)str % alignment;
    char *start = mod == 0 ? str : (str + alignment - mod);
    char *end = str + sizeof(str);
    end -= (NSUInteger)end % alignment;
    for (NSInteger i = 0; i < sizeof(str); i++) {
        str[i] = rand() % 2 == 0 ? '"' : 'a' + rand() % 26;
    }
    // process_chars(start, end - start, dest);
    FFOTestProcessChars(start, dest, end - start);
    // It's ok if end < start, that will be checked for
    // [self _beginMonitoringStacks];
    BENCH("mine", ({
        process_chars(start, end - start, dest);
    }));
    return;
    BENCH("sum", (int64_t)({
        NSInteger sum = 0;
        for (NSInteger i = 0; i < sizeof(str); i++) {
            sum += str[i];
        }
        str[0] = rand() % 26 + 'a';
        sum;
    }));
}

@end
