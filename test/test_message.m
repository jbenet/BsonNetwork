//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BNMessage.h"
#import "RandomObjects.h"
#import "BSONCodec.h"

#define kARC4RANDOM_MAX      (0x100000000)
#define kARC4RANDOM_FLOAT    (arc4random() * 1.0 / kARC4RANDOM_MAX)


@interface BNMessageTest : GHTestCase {}
@end

@implementation BNMessageTest

//------------------------------------------------------------------------------
#pragma mark setup

- (BOOL) shouldRunOnMainThread {
  return NO;
}

- (void) setUpClass {}
- (void) tearDownClass {}
- (void) setUp {}
- (void) tearDown {}


//------------------------------------------------------------------------------
#pragma mark check in expect

- (void) testM_messageSimple {
  BNMessage *msg = [[BNMessage alloc] init];
  GHAssertFalse([msg isAddressed], @"addr");
  GHAssertFalse([msg containsKey:BNMessageSource], @"addr");
  GHAssertFalse([msg containsKey:BNMessageDestination], @"addr");
  GHAssertFalse([msg containsKey:@"dasfafdes"], @"addr");
  GHAssertFalse([msg containsKey:@"dasfafrewqreqreqwdes"], @"addr");

  msg.source = @"herp";
  GHAssertFalse([msg isAddressed], @"src");
  GHAssertTrue([msg containsKey:BNMessageSource], @"src");
  GHAssertFalse([msg containsKey:BNMessageDestination], @"src");
  GHAssertTrue([msg.source isEqualToString:@"herp"], @"src");

  msg.destination = @"derp";
  GHAssertTrue([msg isAddressed], @"dest");
  GHAssertTrue([msg containsKey:BNMessageSource], @"dest");
  GHAssertTrue([msg containsKey:BNMessageDestination], @"dest");
  GHAssertTrue([msg.destination isEqualToString:@"derp"], @"dest");

  [msg.contents setValue:@"fdiosajfidas" forKey:@"dsaiofidsajfdsa"];
  GHAssertTrue([[msg.contents valueForKey:@"dsaiofidsajfdsa"]
    isEqualToString:@"fdiosajfidas"], @"val");
  [msg release];
}

- (void) testM_messageReliable {
  BNMessage *msg = [[BNMessage alloc] init];

  GHAssertFalse([msg isReliableMessage], @"reliable");
  GHAssertFalse([msg containsKey:BNMessageAckNo], @"reliable");
  GHAssertFalse([msg containsKey:BNMessageSeqNo], @"reliable");

  msg.ackNo = 4124321;
  GHAssertFalse([msg isReliableMessage], @"reliable");
  GHAssertTrue([msg containsKey:BNMessageAckNo], @"reliable");
  GHAssertFalse([msg containsKey:BNMessageSeqNo], @"reliable");
  GHAssertTrue(msg.ackNo == 4124321, @"reliable");

  msg.seqNo = 654365;
  GHAssertTrue([msg isReliableMessage], @"reliable");
  GHAssertTrue([msg containsKey:BNMessageAckNo], @"reliable");
  GHAssertTrue([msg containsKey:BNMessageSeqNo], @"reliable");
  GHAssertTrue(msg.seqNo == 654365, @"reliable");
  [msg release];
}

- (void) testM_messageToken{
  BNMessage *msg = [[BNMessage alloc] init];

  GHAssertFalse([msg containsKey:BNMessageToken], @"token");
  GHAssertTrue(msg.token == 0, @"token");

  msg.token = 13143124;
  GHAssertTrue([msg containsKey:BNMessageToken], @"token");
  GHAssertTrue(msg.token == 13143124, @"token");
  [msg release];
}

@end



@interface BNMessageQueueSender : NSObject {
  NSMutableArray *inArr1;
  NSMutableArray *inArr2;
  BNMessageQueue *q1;
  BNMessageQueue *q2;
  NSMutableArray *outArr1;
  NSMutableArray *outArr2;
  int lastSent1;
  int lastSent2;
}
@end

@implementation BNMessageQueueSender

- (id) init {
  if ((self = [super init])) {
    inArr1 = [[NSMutableArray alloc] init];
    inArr2 = [[NSMutableArray alloc] init];
    q1 = [[BNMessageQueue alloc] init];
    q2 = [[BNMessageQueue alloc] init];
    outArr1 = [[NSMutableArray alloc] init];
    outArr2 = [[NSMutableArray alloc] init];
    lastSent1 = 0;
    lastSent2 = 0;
  }
  return self;
}

- (void) dealloc {
  [inArr1 release];
  [inArr2 release];
  [q1 release];
  [q2 release];
  [outArr1 release];
  [outArr2 release];
  [super dealloc];
}

- (void) inputMessage1:(BNMessage *)message {
  [inArr1 addObject:message];
}

- (void) inputMessage2:(BNMessage *)message {
  [inArr2 addObject:message];
}

- (BOOL) inputArray:(NSArray *)inArr isEqualToOutputArray:(NSArray *)outArr {
  if ([outArr count] != [inArr count])
    return NO;

  for (int i = 0; i < [inArr count]; i++) {
    BNMessage *mi = [inArr objectAtIndex:i];
    BNMessage *mo = [outArr objectAtIndex:i];

    NSData *dai = [mi.contents BSONRepresentation];
    NSData *dao = [mo.contents BSONRepresentation];

    if (![dai isEqualToData:dao])
      [NSException raise:@"BNMessagesNotEqual" format: @"Messages not equal"];
  }

  for (int i = 0; i < [inArr2 count]; i++) {
    BNMessage *mi = [inArr2 objectAtIndex:i];
    BNMessage *mo = [outArr2 objectAtIndex:i];

    NSData *dai = [mi.contents BSONRepresentation];
    NSData *dao = [mo.contents BSONRepresentation];

    if (![dai isEqualToData:dao])
      [NSException raise:@"BNMessagesNotEqual" format: @"Messages not equal"];
  }

  return YES;
}


- (BOOL) done {

  return ([self inputArray:inArr1 isEqualToOutputArray:outArr1]
       && [self inputArray:inArr2 isEqualToOutputArray:outArr2]);

}

- (BNMessage *) msgForMsg:(BNMessage *)msg {
  NSData *data = [msg.contents BSONRepresentation];
  return [BNMessage messageWithContents:[data BSONValue]];
}

- (BOOL) runWithLoss:(float)loss {

  long int runTimes = MAX([inArr1 count], [inArr2 count]) * 1000;
  for (int i = 0; i < runTimes; i++) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    if (i % 100 == 0)
      [NSThread sleepForTimeInterval:0.01];

    if ([self done]) {
      [pool drain];
      break;
    }

//    [NSThread sleepForTimeInterval:0.25];

    if (lastSent1 < [inArr1 count]) {
      BNMessage *mi = [inArr1 objectAtIndex:lastSent1++];
      [q1 enqueueSendMessage:mi];
    }

    if (lastSent2 < [inArr2 count]) {
      BNMessage *mi = [inArr2 objectAtIndex:lastSent2++];
      [q2 enqueueSendMessage:mi];
    }

    BNMessage *m1 = [q1 dequeueSendMessage];
    BNMessage *m2 = [q2 dequeueSendMessage];

    if (m1 && kARC4RANDOM_FLOAT >= loss)
      [q2 enqueueRecvMessage:[self msgForMsg:m1]];

    if (m2 && kARC4RANDOM_FLOAT >= loss)
      [q1 enqueueRecvMessage:[self msgForMsg:m2]];

    BNMessage *mo = [q2 dequeueRecvMessage];
    if (mo)
      [outArr1 addObject:mo];

    mo = [q1 dequeueRecvMessage];
    if (mo)
      [outArr2 addObject:mo];

    [pool drain];
  }

  NSLog(@"q1 %@", [q1 statsString]);
  NSLog(@"q2 %@", [q2 statsString]);

  return [self done];
}

@end


@interface BNMessageQueueTest : GHTestCase {
  BNMessageQueue *q1;
  BNMessageQueue *q2;
}
@end

@implementation BNMessageQueueTest

//------------------------------------------------------------------------------
#pragma mark setup

- (BOOL) shouldRunOnMainThread {
  return NO;
}

- (void) setUpClass {}
- (void) tearDownClass {}
- (void) setUp {}
- (void) tearDown {}


- (void) testAA_Basic {
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"fafdsafdsa",
    @"iojiorewjo", @"uououpoiupoiuou", @"$tregt", nil];

  BNMessage *msg = [BNMessage messageWithContents:dict];


  BNMessageQueue *qq1 = [[BNMessageQueue alloc] init];
  BNMessageQueue *qq2 = [[BNMessageQueue alloc] init];

  GHAssertTrue([qq1 dequeueRecvMessage] == nil, @"nil");
  GHAssertTrue([qq2 dequeueRecvMessage] == nil, @"nil");
  
  BNMessage *ack = [qq1 dequeueSendMessage];
  GHAssertTrue(ack != nil, @"nil");
  GHAssertTrue(ack.seqNo == 0, @"zero");
  GHAssertTrue(ack.ackNo == 0, @"zero");
  GHAssertTrue([ack isReliableMessage], @"reliable");
  GHAssertTrue([qq1 dequeueSendMessage] == nil, @"nil");
  
  ack = [qq2 dequeueSendMessage];
  GHAssertTrue(ack != nil, @"nil");
  GHAssertTrue(ack.seqNo == 0, @"zero");
  GHAssertTrue(ack.ackNo == 0, @"zero");
  GHAssertTrue([ack isReliableMessage], @"reliable");
  GHAssertTrue([qq2 dequeueSendMessage] == nil, @"nil");

  [qq1 enqueueSendMessage:msg];
  BNMessage *send = [qq1 dequeueSendMessage];
  GHAssertTrue(msg == send, @"equal");
  GHAssertTrue(msg.seqNo == 1, @"one");
  GHAssertTrue(msg.ackNo == 0, @"zero");
  GHAssertTrue([msg isReliableMessage], @"reliable");

  [qq2 enqueueRecvMessage:send];
  BNMessage *recv = [qq2 dequeueRecvMessage];
  GHAssertTrue(send == recv, @"equal");

  ack = [qq2 dequeueSendMessage];
  GHAssertTrue(ack != nil, @"nil");
  GHAssertTrue(ack.seqNo == 0, @"zero");
  GHAssertTrue(ack.ackNo == 1, @"one");
  GHAssertTrue(ack.ackNo == send.seqNo, @"one");
  GHAssertTrue([ack isReliableMessage], @"reliable");
  
  [qq1 release];
  [qq2 release];
}

- (void) testA_SimpleOneWay {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"fafdsafdsa",
    @"iojiorewjo", @"uououpoiupoiuou", @"$tregt", nil];

  BNMessage *msg = [BNMessage messageWithContents:dict];
  [s inputMessage1:msg];
  GHAssertTrue([s runWithLoss:0.0], @"running");
  [s release];
}


- (void) testBA_100_OneWay {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 100; i++) {
    NSDictionary *dict = [NSDictionary randomDictionary];
    BNMessage *msg = [BNMessage messageWithContents:dict];
    [s inputMessage1:msg];
  }

  GHAssertTrue([s runWithLoss:0.0], @"running");
  [s release];
}

- (void) testBB_100_OneWay_loss_20 {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 100; i++) {
    NSDictionary *dict = [NSDictionary randomDictionary];
    BNMessage *msg = [BNMessage messageWithContents:dict];
    [s inputMessage1:msg];
  }

  GHAssertTrue([s runWithLoss:0.2], @"running");
  [s release];
}

- (void) testBC_100_OneWay_loss_40 {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 100; i++) {
    NSDictionary *dict = [NSDictionary randomDictionary];
    BNMessage *msg = [BNMessage messageWithContents:dict];
    [s inputMessage1:msg];
  }

  GHAssertTrue([s runWithLoss:0.4], @"running");
  [s release];
}

- (void) testBD_100_OneWay_loss_80 {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 100; i++) {
    NSDictionary *dict = [NSDictionary randomDictionary];
    BNMessage *msg = [BNMessage messageWithContents:dict];
    [s inputMessage1:msg];
  }

  GHAssertTrue([s runWithLoss:0.8], @"running");
  [s release];
}

- (void) testCA_1000_OneWay {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 1000; i++) {
    NSDictionary *dict = [NSDictionary randomDictionary];
    BNMessage *msg = [BNMessage messageWithContents:dict];
    [s inputMessage1:msg];
  }

  GHAssertTrue([s runWithLoss:0.0], @"running");
  [s release];
}


- (void) testDA_10000_OneWay {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 10000; i++) {
    NSDictionary *dict = [NSDictionary randomDictionary];
    BNMessage *msg = [BNMessage messageWithContents:dict];
    [s inputMessage1:msg];
  }

  GHAssertTrue([s runWithLoss:0.0], @"running");
  [s release];
}

- (void) testDB_10000_OneWay_loss_20 {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 10000; i++) {
    NSDictionary *dict = [NSDictionary randomDictionary];
    BNMessage *msg = [BNMessage messageWithContents:dict];
    [s inputMessage1:msg];
  }

  GHAssertTrue([s runWithLoss:0.2], @"running");
  [s release];
}

- (void) testDC_10000_OneWay_loss_40 {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 10000; i++) {
    NSDictionary *dict = [NSDictionary randomDictionary];
    BNMessage *msg = [BNMessage messageWithContents:dict];
    [s inputMessage1:msg];
  }

  GHAssertTrue([s runWithLoss:0.4], @"running");
  [s release];
}

- (void) testDD_10000_OneWay_loss_80 {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 10000; i++) {
    NSDictionary *dict = [NSDictionary randomDictionary];
    BNMessage *msg = [BNMessage messageWithContents:dict];
    [s inputMessage1:msg];
  }

  GHAssertTrue([s runWithLoss:0.8], @"running");
  [s release];
}


- (void) testEAA_SimpleTwoWay {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"fafdsafdsa",
    @"iojiorewjo", @"uououpoiupoiuou", @"$tregt", nil];

  BNMessage *msg = [BNMessage messageWithContents:dict];
  [s inputMessage1:msg];
  GHAssertTrue([s runWithLoss:0.0], @"running");
  [s release];
}


- (void) testEA_100_TwoWay {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 100; i++) {
    NSDictionary *dict1 = [NSDictionary randomDictionary];
    NSDictionary *dict2 = [NSDictionary randomDictionary];
    BNMessage *msg1 = [BNMessage messageWithContents:dict1];
    BNMessage *msg2 = [BNMessage messageWithContents:dict2];
    [s inputMessage1:msg1];
    [s inputMessage1:msg2];
  }


  GHAssertTrue([s runWithLoss:0.0], @"running");
  [s release];
}

- (void) testEB_100_TwoWay_loss_20 {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 100; i++) {
    NSDictionary *dict1 = [NSDictionary randomDictionary];
    NSDictionary *dict2 = [NSDictionary randomDictionary];
    BNMessage *msg1 = [BNMessage messageWithContents:dict1];
    BNMessage *msg2 = [BNMessage messageWithContents:dict2];
    [s inputMessage1:msg1];
    [s inputMessage1:msg2];
  }

  GHAssertTrue([s runWithLoss:0.2], @"running");
  [s release];
}

- (void) testEC_100_TwoWay_loss_40 {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 100; i++) {
    NSDictionary *dict1 = [NSDictionary randomDictionary];
    NSDictionary *dict2 = [NSDictionary randomDictionary];
    BNMessage *msg1 = [BNMessage messageWithContents:dict1];
    BNMessage *msg2 = [BNMessage messageWithContents:dict2];
    [s inputMessage1:msg1];
    [s inputMessage1:msg2];
  }

  GHAssertTrue([s runWithLoss:0.4], @"running");
  [s release];
}

- (void) testED_100_TwoWay_loss_80 {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 100; i++) {
    NSDictionary *dict1 = [NSDictionary randomDictionary];
    NSDictionary *dict2 = [NSDictionary randomDictionary];
    BNMessage *msg1 = [BNMessage messageWithContents:dict1];
    BNMessage *msg2 = [BNMessage messageWithContents:dict2];
    [s inputMessage1:msg1];
    [s inputMessage1:msg2];
  }

  GHAssertTrue([s runWithLoss:0.8], @"running");
  [s release];
}

- (void) testFA_1000_TwoWay {

  BNMessageQueueSender *s = [[BNMessageQueueSender alloc] init];

  for (int i = 0; i < 100; i++) {
    NSDictionary *dict1 = [NSDictionary randomDictionary];
    NSDictionary *dict2 = [NSDictionary randomDictionary];
    BNMessage *msg1 = [BNMessage messageWithContents:dict1];
    BNMessage *msg2 = [BNMessage messageWithContents:dict2];
    [s inputMessage1:msg1];
    [s inputMessage1:msg2];
  }


  GHAssertTrue([s runWithLoss:0.0], @"running");
  [s release];
}

@end
