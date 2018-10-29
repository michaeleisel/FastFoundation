//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <malloc/malloc.h>

#if 1
#define je_free free
#define je_malloc malloc
#define je_realloc realloc
#define je_orig_default_zone malloc_default_zone()
#endif
