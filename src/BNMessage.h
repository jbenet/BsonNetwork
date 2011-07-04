//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2011.
//  MIT License, see LICENSE file for details.
//

#import <Foundation/Foundation.h>

extern NSString * const BNMessageSource;
extern NSString * const BNMessageDestination;
extern NSString * const BNMessageSeqNo;
extern NSString * const BNMessageAckNo;
extern NSString * const BNMessageToken;


@interface BNMessage : NSObject {
  NSMutableDictionary *contents;
}

@property (nonatomic, retain) NSString *source;
@property (nonatomic, retain) NSString *destination;
@property (readonly) NSMutableDictionary *contents;

- (BOOL) isAddressed;
- (BOOL) containsKey:(NSString *)key;
+ (BNMessage *) messageWithContents:(NSDictionary *)dictionary;

@end

@protocol BNMessageSender <NSObject>
- (BOOL) sendMessage:(BNMessage *)message;
@end



@interface BNMessage (Reliable)
@property (nonatomic, assign) NSUInteger ackNo;
@property (nonatomic, assign) NSUInteger seqNo;
- (BOOL) isReliableMessage;
@end


@interface BNMessage (Token)
@property (nonatomic, assign) NSUInteger token;
@end



typedef struct {
  uint unique;
  uint absolute;
  uint duplicate;
  uint consumed;
  uint ackonly;
} BNMessageStats;

// for reliability when using a router in between.
@interface BNMessageQueue : NSObject {
  NSMutableDictionary *sendTimes_;
  NSMutableArray *sendQueue_;
  NSMutableArray *recvQueue_;

  NSUInteger nextSeqNo_;
  NSUInteger cumAckNo_;

  BNMessageStats sendStats_;
  BNMessageStats recvStats_;

  NSTimeInterval resendTimeInterval;
}

@property (assign) NSTimeInterval resendTimeInterval;

- (NSString *) statsString;
- (NSUInteger) cumulativeAckNo;

- (BNMessage *) dequeueRecvMessage;               // incoming data ready
- (void) enqueueRecvMessage:(BNMessage *)message; // incoming data to process

- (BNMessage *) dequeueSendMessage;               // outgoing data to go
- (void) enqueueSendMessage:(BNMessage *)message; // outgoing data to process

@end
