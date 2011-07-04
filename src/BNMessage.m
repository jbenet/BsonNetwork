
//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BsonNetwork.h"


NSString * const BNMessageSource = @"_src";
NSString * const BNMessageDestination = @"_dst";
NSString * const BNMessageSeqNo = @"_seq";
NSString * const BNMessageAckNo = @"_ack";
NSString * const BNMessageToken = @"_tok";

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark BNMessage

@implementation BNMessage

@synthesize contents;

- (id) init {
  if ((self = [super init])) {
    contents = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void) dealloc {
  [contents release];
  [super dealloc];
}

- (BOOL) isAddressed {
  return [self containsKey:BNMessageSource] &&
         [self containsKey:BNMessageDestination];
}

- (NSString *) source {
  return [contents valueForKey:BNMessageSource];
}

- (void) setSource:(NSString *)source {
  [contents setValue:source forKey:BNMessageSource];
}


- (NSString *) destination {
  return [contents valueForKey:BNMessageDestination];
}

- (void) setDestination:(NSString *)destination {
  [contents setValue:destination forKey:BNMessageDestination];
}

- (BOOL) containsKey:(NSString *)key {
  return [contents valueForKey:key] != nil;
}

+ (BNMessage *) messageWithContents:(NSDictionary *)dictionary {
  BNMessage *msg = [[BNMessage alloc] init];
  [msg.contents addEntriesFromDictionary:dictionary];
  return [msg autorelease];
}

@end

//------------------------------------------------------------------------------
#pragma mark -

@implementation BNMessage (Reliable)
- (NSUInteger) ackNo {
  return [[contents valueForKey:BNMessageAckNo] intValue];
}

- (void) setAckNo:(NSUInteger)ackNo {
  [contents setValue:[NSNumber numberWithLong:ackNo] forKey:BNMessageAckNo];
}

- (NSUInteger) seqNo {
  return [[contents valueForKey:BNMessageSeqNo] intValue];
}

- (void) setSeqNo:(NSUInteger)seqNo {
  [contents setValue:[NSNumber numberWithLong:seqNo] forKey:BNMessageSeqNo];
}

- (BOOL) isReliableMessage {
  return [self containsKey:BNMessageSeqNo] && [self containsKey:BNMessageAckNo];
}
@end

//------------------------------------------------------------------------------
#pragma mark -

@implementation BNMessage (Token)
- (NSUInteger) token {
  return [[contents valueForKey:BNMessageToken] intValue];
}

- (void) setToken:(NSUInteger)token {
  [contents setValue:[NSNumber numberWithLong:token] forKey:BNMessageToken];
}

@end


//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark BNMessage


@implementation BNMessageQueue

- (id) init {
  if ((self = [super init])) {
    sendTimes_ = [[NSMutableDictionary alloc] initWithCapacity:10];
    sendQueue_ = [[NSMutableArray alloc] initWithCapacity:10];
    recvQueue_ = [[NSMutableArray alloc] initWithCapacity:10];

    nextSeqNo_ = 1;
    cumAckNo_ = 0;

    resendTimeInterval = 0.030; // 30 milliseconds.
  }
  return self;
}

- (void) dealloc {
  [sendTimes_ release];
  [sendQueue_ release];
  [recvQueue_ release];
  [super dealloc];
}

//------------------------------------------------------------------------------

- (NSTimeInterval) resendTimeInterval {
  @synchronized(sendQueue_) {
    return resendTimeInterval;
  }
}

- (void) setResendTimeInterval:(NSTimeInterval)timeInterval {
  @synchronized(sendQueue_) {
    resendTimeInterval = timeInterval;
  }
}

//------------------------------------------------------------------------------

- (void) __handleAckNo:(NSUInteger)ackNo {
  @synchronized(sendQueue_) {
    for (int i = 0; i < [sendQueue_ count]; i++) {
      BNMessage *msg = [sendQueue_ objectAtIndex:i];
      if (msg.seqNo <= ackNo) {
        NSString *key = [NSString stringWithFormat:@"%d", msg.seqNo];
        [sendQueue_ removeObjectAtIndex:i];
        sendStats_.consumed++;
        [sendTimes_ setValue:nil forKey:key]; // clear out entry
      }
    }
  }
}

- (NSUInteger) cumulativeAckNo {
  @synchronized(recvQueue_) {
    return cumAckNo_;
  }
}

//------------------------------------------------------------------------------

- (BNMessage *) dequeueRecvMessage {
  @synchronized(recvQueue_) {
    if ([recvQueue_ count] == 0)
      return nil; // nothing to receive

    BNMessage *msg = [recvQueue_ objectAtIndex:0];
    if (msg.seqNo > cumAckNo_ + 1)
      return nil; // missing some in between

    if (msg.seqNo == cumAckNo_ + 1)
      cumAckNo_ = msg.seqNo;

    recvStats_.consumed++;
    [msg retain];
    [recvQueue_ removeObjectAtIndex:0];
    return [msg autorelease];
  }
}

- (void) enqueueRecvMessage:(BNMessage *)message {
  if (![message isReliableMessage]) {
    [NSException raise:@"BNMessageUnreliable"
      format:@"BNMessage is not reliable (no _ack or _seq keys)."];
  }

  [self __handleAckNo:message.ackNo];
  @synchronized(recvQueue_) {
    recvStats_.absolute++;

    if (message.seqNo == 0) {
      recvStats_.ackonly++;
      return; // no data, just ack.
    }

    if (message.seqNo <= cumAckNo_) {
      // already consumed it. drop it.
      // DebugLog(@"Received Duplicate Message (consumed).");
      recvStats_.duplicate++;
      return;
    }

    int i = 0;
    for (; i < [recvQueue_ count]; i++) {
      BNMessage *curr = [recvQueue_ objectAtIndex:i];
      if (message.seqNo == curr.seqNo) {
        // already have it. drop it.
        // DebugLog(@"Received Duplicate Message.");
        recvStats_.duplicate++;
        return;
      } else if (message.seqNo < curr.seqNo) {
        // belongs right here.
        break;
      }
    }

    recvStats_.unique++;
    [recvQueue_ insertObject:message atIndex:i];
  }

  @synchronized(sendQueue_) {
    // got something. allow single acks again regardless of timeout.
    [sendTimes_ setValue:nil forKey:@"ack"];
  }
}

//------------------------------------------------------------------------------

- (BNMessage *) dequeueSendMessage {
  NSUInteger ackNoToSend = [self cumulativeAckNo];
    // need to do this here to avoid contention. sure, the ackno may be slightly
    // outdated (in the order of microseconds) but its not a problem for this
    // thing anyway.

  @synchronized(sendQueue_) {
    if ([sendQueue_ count] > 0) {
      // data to send!
      for (BNMessage *msg in sendQueue_) {

        NSString *key = [NSString stringWithFormat:@"%d", msg.seqNo];
        NSDate *lastSent = [sendTimes_ valueForKey:key];
        if (lastSent == nil) {
          // never sent this before!
          sendStats_.unique++;
        }
        else if ([lastSent timeIntervalSinceNow] < -1.0 * resendTimeInterval) {
          // time to resend!
          sendStats_.duplicate++;
        }
        else {
          // dont resend this one yet. choose another.
          continue;
        }

        // Ok this one's good to send.
        sendStats_.absolute++;
        [sendTimes_ setValue:[NSDate date] forKey:key];
        msg.ackNo = ackNoToSend;
        return msg;
      }
    }

    NSDate *lastSent = [sendTimes_ valueForKey:@"ack"];
    if (lastSent && [lastSent timeIntervalSinceNow] > -1.0 * resendTimeInterval)
      return nil; // sent an ackonly message too soon. wait.

    [sendTimes_ setValue:[NSDate date] forKey:@"ack"];
    sendStats_.ackonly++;
    sendStats_.absolute++;
  }

  BNMessage *msg = [[BNMessage alloc] init];
  msg.ackNo = ackNoToSend;
  msg.seqNo = 0;
  return [msg autorelease];
}

- (void) enqueueSendMessage:(BNMessage *)message {
  @synchronized(sendQueue_) {
    message.ackNo = 0;
    message.seqNo = nextSeqNo_;
    nextSeqNo_++;
    [sendQueue_ addObject:message];
  }
}


- (NSString *) statsString {
  NSMutableString *str = [NSMutableString string];
  [str appendString: @"QSTATS: "];

  @synchronized(sendQueue_) {
    [str appendFormat:@" Send(%d, %d): ", [sendQueue_ count], nextSeqNo_];
    [str appendFormat: @"abs:%d ", sendStats_.absolute];
    [str appendFormat: @"dup:%d ", sendStats_.duplicate];
    [str appendFormat: @"unq:%d ", sendStats_.unique];
    [str appendFormat: @"con:%d ", sendStats_.consumed];
    [str appendFormat: @"ack:%d ", sendStats_.ackonly];
    [str appendFormat: @"tim:%d ", [sendTimes_ count]];
  }

  @synchronized(recvQueue_) {
    [str appendFormat:@" Recv(%d, %d): ", [recvQueue_ count], cumAckNo_];
    [str appendFormat: @"abs:%d ", recvStats_.absolute];
    [str appendFormat: @"dup:%d ", recvStats_.duplicate];
    [str appendFormat: @"unq:%d ", recvStats_.unique];
    [str appendFormat: @"con:%d ", recvStats_.consumed];
    [str appendFormat: @"ack:%d ", recvStats_.ackonly];
  }


  return str;
}

@end






