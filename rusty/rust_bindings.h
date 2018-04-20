#import <Foundation/Foundation.h>

const char *FFOComponentsJoinedByString_Rust(const char *const *values,
                                             uint32_t values_len,
                                             const char *joiner);

void FFORustDeallocate(void *ptr, void *info);
