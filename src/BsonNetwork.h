//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BNConnection.h"
#import "BNServer.h"
#import "BNNode.h"
#import "BNRemoteService.h"
#import "BNMessage.h"

#ifdef DEBUG
#define BSONNETWORK_DEBUG
#endif

#ifndef DebugLog
  #ifdef BSONNETWORK_DEBUG
    #define DebugLog(fmt, ...) NSLog((@"%s [line %d] " fmt), \
              __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
  #else
    #define DebugLog(...)
  #endif
#endif
