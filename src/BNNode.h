//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2011.
//  MIT License, see LICENSE file for details.
//

#import <Foundation/Foundation.h>
#import "BNServer.h"
#import "BNConnection.h"





@class BNLink;
@class BNMessage;
@class BNNode;

@protocol BNNodeDelegate <NSObject>
- (void) node:(BNNode *)node error:(NSError *)error;
@end


// Notifications Thrown:
extern NSString * const BNNodeConnectedLinkNotification;
extern NSString * const BNNodeDisconnectedLinkNotification;

extern NSString * const BNNodeReceivedMessageNotification;
extern NSString * const BNNodeSentMessageNotification;



@interface BNNode : NSObject <BNServerDelegate, BNConnectionDelegate> {
  NSMutableDictionary * links_;

  NSString *name;
  BNServer * server;
  BNLink * defaultLink;
  id<BNNodeDelegate> delegate;
}

@property (copy, readonly) NSString * name;
@property (readonly) BNServer * server;
@property (assign) id<BNNodeDelegate> delegate;

@property (assign) BNLink * defaultLink;

- (id) initWithName:(NSString *)name;
- (id) initWithName:(NSString *)name andThread:(NSThread *)thread;

- (BNLink *) linkForName:(NSString *)linkName;
- (void) disconnectLinks;

- (BOOL) sendMessage:(BNMessage *)message;

@end




@interface BNLink : NSObject {
  NSString * name;
  BNConnection * connection;
}

@property (copy, readonly) NSString * name;
@property (readonly) BNConnection * connection;

- (id) initWithName:(NSString *)name andConnection:(BNConnection *)conn;

- (BOOL) sendMessage:(BNMessage *)message;
- (void) disconnect;

@end




@interface BNMessage : NSObject {
  NSMutableDictionary *contents;
}

@property (nonatomic, retain) NSString *source;
@property (nonatomic, retain) NSString *destination;
@property (readonly) NSMutableDictionary *contents;

+ (BNMessage *) messageWithContents:(NSDictionary *)dictionary;

@end


@interface BNMessageNotification : NSNotification {
  BNNode *node;
  BNLink *link;
  BNMessage *message;
}

@property (retain) BNNode *node;
@property (retain) BNLink *link;
@property (retain) BNMessage *message;

+ (BNMessageNotification *) notificationWithName:(NSString *)name
  node:(BNNode *)node link:(BNLink *)link message:(BNMessage *) message;

+ (BNMessageNotification *) sentMessageNotificationWithNode:(BNNode *)node
  link:(BNLink *)link message:(BNMessage *) message;

+ (BNMessageNotification *) receivedMessageNotificationWithNode:(BNNode *)node
  link:(BNLink *)link message:(BNMessage *) message;

@end