//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2011.
//  MIT License, see LICENSE file for details.
//

#import <Foundation/Foundation.h>
#import "BNMessage.h"
#import "BNNode.h"


@class BNRemoteService;

@protocol BNRemoteServiceDelegate <NSObject>
- (void) remoteService:(BNRemoteService *)serv receivedMessage:(BNMessage *)msg;
- (void) remoteService:(BNRemoteService *)serv error:(NSError *)error;
@optional
- (void) remoteService:(BNRemoteService *)serv sentMessage:(BNMessage *)msg;
@end


// Notifications Thrown:
extern NSString * const BNRemoteServiceReceivedMessageNotification;
extern NSString * const BNRemoteServiceSentMessageNotification;


@interface BNRemoteService : NSObject <BNMessageSender> {
  BNNode * node;
  NSString * name;
  id<BNRemoteServiceDelegate> delegate;

  NSDate * lastReceivedDate;
  BNMessage * lastReceivedMessage;
}

@property (readonly) BNNode * node;
@property (readonly) NSString * name;
@property (assign) id<BNRemoteServiceDelegate> delegate;

@property (readonly) NSDate * lastReceivedDate;
@property (readonly) BNMessage * lastReceivedMessage;

- (id) initWithName:(NSString *)name andNode:(BNNode *)node;

- (BOOL) sendMessage:(BNMessage *)message;
- (BOOL) sendDictionary:(NSDictionary *)message;

@end

@class BNMessageQueue;

@interface BNReliableRemoteService : BNRemoteService {
  BNMessageQueue *queue_;
  NSTimer *periodicTimer_;
  int periodicTrickleTimeout_;
  int nextTrickleTimeout_;
}

- (void) invalidateTimer;

@end