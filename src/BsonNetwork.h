

#import "BNConnection.h"
#import "BNServer.h"

// #ifdef DEBUG
#define BSONNETWORK_DEBUG
// #endif

#ifndef DebugLog
  #ifdef BSONNETWORK_DEBUG
    #define DLog(fmt, ...) NSLog((@"%s [line %d] " fmt), \
              __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
  #else
    #define DLog(...)
  #endif
#endif
