//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BNNode.h"
#import "RandomObjects.h"

#ifndef WAIT_WHILE
#define WAIT_WHILE(condition) \
  for (int i = 0; (condition) && i < 10000; i++) \
    [NSThread sleepForTimeInterval:0.5]; // main thread apparently.
#endif

@interface BNNodeTest : GHTestCase <BNNodeDelegate> {

  NSMutableArray *links;
  NSMutableDictionary *nodes;
  NSMutableDictionary *expect;

}

@end

@implementation BNNodeTest

//------------------------------------------------------------------------------
#pragma mark setup

- (BOOL) shouldRunOnMainThread {
  return NO;
}

- (void) setupNodeWithNumber:(NSNumber *)number {
  NSLog(@"Setting up node at %@", number);
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  int num = [number intValue];
  NSString *name = [NSString stringWithFormat:@"client%d", num];
  UInt16 port = 1340 + num;

  BNNode *node = [[BNNode alloc] initWithName:name];
  node.delegate = self;
  @synchronized(nodes) {
    [nodes setValue:node forKey:name];
  }
  [node release];

  @synchronized(expect) {
    [expect setValue:[NSMutableArray array] forKey:name];
  }

  GHAssertFalse(node.server.isListening, @"shouldn't be listening yet...");
  GHAssertTrue([node.server startListeningOnPort:port],
    @"Should be able to begin listening.");

  [[NSRunLoop currentRunLoop] run];

  [pool release];
}

- (void) setUpClass {

  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(connectedLinkNotification:)
    name:BNNodeConnectedLinkNotification object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(disconnectedLinkNotification:)
    name:BNNodeDisconnectedLinkNotification object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(receivedMessageNotification:)
    name:BNNodeReceivedMessageNotification object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(sentMessageNotification:)
    name:BNNodeSentMessageNotification object:nil];


  links = [[NSMutableArray alloc] initWithCapacity:10];
  nodes = [[NSMutableDictionary alloc] initWithCapacity:10];
  expect = [[NSMutableDictionary alloc] initWithCapacity:10];

  SEL setup = @selector(setupNodeWithNumber:);
  [NSThread detachNewThreadSelector:setup toTarget:self
    withObject:[NSNumber numberWithInt:1]];
  [NSThread detachNewThreadSelector:setup toTarget:self
    withObject:[NSNumber numberWithInt:2]];
  [NSThread detachNewThreadSelector:setup toTarget:self
    withObject:[NSNumber numberWithInt:3]];
  [NSThread detachNewThreadSelector:setup toTarget:self
    withObject:[NSNumber numberWithInt:4]];

  WAIT_WHILE([nodes count] < 4);

}

- (void) tearDownClass {
  [links release];
  [nodes release];
  [expect release];

  links = nil;
  nodes = nil;
  expect = nil;
}

- (void) setUp {
  [NSThread sleepForTimeInterval:0.3];
}

- (void) tearDown {
  [NSThread sleepForTimeInterval:0.3];

  for (NSArray *arr in [expect allValues])
    GHAssertTrue([arr count] == 0, @"Must not be waiting for anything else.");
}

//------------------------------------------------------------------------------
#pragma mark node delegate

- (void) node:(BNNode *)node error:(NSError *)error {
  NSLog(@"Node: %@ error: %@", node, error);
}

//------------------------------------------------------------------------------
#pragma mark check in expect

- (BOOL) nodeNamed:(NSString *)name consumeExpectedData:(NSData *)data {
  @synchronized(expect) {
    NSMutableArray *arr = [expect valueForKey:name];
    for (NSData *xdata in arr) {
      if ([xdata isEqualToData:data]) {
        [arr removeObject:xdata];
        return YES;
      }
    }
  }
  return NO;
}

- (int) expectedCount {
  int count = 0;
  @synchronized(expect) {
    for (NSArray *arr in [expect allValues])
      count += [arr count];
  }
  return count;
}

//------------------------------------------------------------------------------
#pragma mark notifications

- (void) connectedLinkNotification:(NSNotification *) notification {
  BNLink *link = [notification.userInfo valueForKey:@"link"];
  GHAssertFalse([links containsObject:link], @"should not contain link");

  [links addObject:link];
}

- (void) disconnectedLinkNotification:(NSNotification *) notification {
  BNLink *link = [notification.userInfo valueForKey:@"link"];
  GHAssertTrue([links containsObject:link], @"should contain link");

  [links removeObject:[notification.userInfo valueForKey:@"link"]];
}

- (void) sentMessageNotification:(NSNotification *) notification {

  BNMessage *message = [notification.userInfo valueForKey:@"message"];
  BNNode *node = notification.object;
  GHAssertTrue([node.name isEqualToString:message.source],
               @"sending node should be the source");

}

- (void) receivedMessageNotification:(NSNotification *) notification {

  BNMessage *message = [notification.userInfo valueForKey:@"message"];
  BNNode *node = notification.object;
  GHAssertTrue([node.name isEqualToString:message.destination],
    @"receiving node should be the destination");

  NSData *bson = [message.contents BSONRepresentation];

  GHAssertTrue([self nodeNamed:message.destination consumeExpectedData:bson],
      @"Expected message not received.");

}

//------------------------------------------------------------------------------
#pragma mark helpers

- (void) waitForAllExpected {
  WAIT_WHILE([self expectedCount] > 0);
  GHAssertTrue([self expectedCount] == 0, @"Should be expecting nothing else.");
}


//------------------------------------------------------------------------------
#pragma mark tests

- (void) testAA_cleaninit {
  for (BNNode *node in [nodes allValues]) {
    GHAssertNil(node.defaultLink, @"Should be nil.");
    GHAssertEqualObjects(node.delegate, self, @"Should be equal.");
  }
}

- (void) testAB_listening {
  for (BNNode *node in [nodes allValues])
    GHAssertTrue(node.server.isListening, @"Should be listening now.");
}

- (void) testBA_simpleConnect {

  BNNode *node1 = [nodes valueForKey:@"client1"];
  BNNode *node2 = [nodes valueForKey:@"client2"];
  [node1.server connectToAddress:@"localhost:1342"];

  WAIT_WHILE([links count] < 2);

  BNLink *l1 = [links objectAtIndex:0];
  BNLink *l2 = [links objectAtIndex:1];
  GHAssertNotNil(l1, @"Link should be established.");
  GHAssertNotNil(l2, @"Link should be established.");
  GHAssertNotNil(l1.connection, @"Connection should be established.");
  GHAssertNotNil(l2.connection, @"Connection should be established.");
  GHAssertTrue(l1.connection.isConnected, @"Connection should be established.");
  GHAssertTrue(l2.connection.isConnected, @"Connection should be established.");


  GHAssertTrue(
    ([l1.name isEqualToString:node1.name] &&
     [l2.name isEqualToString:node2.name]) ||
     ([l1.name isEqualToString:node2.name] &&
      [l2.name isEqualToString:node1.name]),
      @"Node names must match.");
}

- (void) testBB_simpleSending {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];
  BNMessage *msg = [BNMessage messageWithContents:dict];
  msg.source = @"client1";
  msg.destination = @"client2";

  BNNode *node1 = [nodes valueForKey:@"client1"];
  BNNode *node2 = [nodes valueForKey:@"client2"];

  NSData *data = [msg.contents BSONRepresentation];

  @synchronized(expect) {
    [[expect valueForKey:node2.name] addObject:data];
  }

  GHAssertTrue([node1 sendMessage:msg], @"Should send ok.");
}

- (void) testBC_simpleResponse {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];
  BNMessage *msg = [BNMessage messageWithContents:dict];
  msg.source = @"client2";
  msg.destination = @"client1";

  BNNode *node1 = [nodes valueForKey:@"client1"];
  BNNode *node2 = [nodes valueForKey:@"client2"];
  NSData *data = [msg.contents BSONRepresentation];
  @synchronized(expect) {
    [[expect valueForKey:node1.name] addObject:data];
  }
  GHAssertTrue([node2 sendMessage:msg], @"Should send ok.");
}

- (void) testBD_simpleSimultaneous {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];

  BNMessage *msg1 = [BNMessage messageWithContents:dict];
  msg1.source = @"client1";
  msg1.destination = @"client2";

  BNMessage *msg2 = [BNMessage messageWithContents:dict];
  msg2.source = @"client2";
  msg2.destination = @"client1";

  BNNode *node1 = [nodes valueForKey:@"client1"];
  BNNode *node2 = [nodes valueForKey:@"client2"];

  NSData *data1 = [msg1.contents BSONRepresentation];
  NSData *data2 = [msg2.contents BSONRepresentation];

  @synchronized(expect) {
    [[expect valueForKey:node1.name] addObject:data2];
    [[expect valueForKey:node2.name] addObject:data1];
  }

  GHAssertTrue([node1 sendMessage:msg1], @"Should send ok.");
  GHAssertTrue([node2 sendMessage:msg2], @"Should send ok.");
}

- (void) testBE_simpleMultiple {

  // Send data between conn1 <-> conn2.
  BNNode *node1 = [nodes valueForKey:@"client1"];
  BNNode *node2 = [nodes valueForKey:@"client2"];

  BNMessage *msg1 = nil;
  BNMessage *msg2 = nil;
  for (int i = 0; i < 10; i++) {
    msg1 = [BNMessage messageWithContents:[NSDictionary randomDictionary]];
    msg2 = [BNMessage messageWithContents:[NSDictionary randomDictionary]];

    msg1.source = @"client1";
    msg2.source = @"client2";
    msg1.destination = @"client2";
    msg2.destination = @"client1";

    NSData *data1 = [msg1.contents BSONRepresentation];
    NSData *data2 = [msg2.contents BSONRepresentation];

    @synchronized(expect) {
      [[expect valueForKey:msg1.destination] addObject:data1];
      [[expect valueForKey:msg2.destination] addObject:data2];
    }

    GHAssertTrue([node1 sendMessage:msg1], @"Sending ok.");
    GHAssertTrue([node2 sendMessage:msg2], @"Sending ok.");
    [self waitForAllExpected];
  }
}

- (void) testBF_simpleMultipleMultiple {
  for (int i = 0; i < 10; i++)
    [self testBE_simpleMultiple];
}

- (void) testBG_simpleDisconnect {

  if ([links count] == 0)
    [self testBA_simpleConnect];

  BNLink *link = [links objectAtIndex:0];
  [link disconnect];

  WAIT_WHILE([links count] > 0);

  GHAssertTrue([links count] == 0, @"Should have no open connections.");

}

- (void) testCA_allConnect {

  NSUInteger nextCount;
  NSString *addr;
  for (BNNode *nA in [nodes allValues]) {
    for (BNNode *nB in [nodes allValues]) {
      if (nA == nB)
        continue;

      if ([nA linkForName:nB.name] && [nB linkForName:nA.name])
        continue;

      // DO test connection to self :) :)
      nextCount = [links count] + 2; // 2 links

      NSLog(@"CONNECTING %@ to %@", nA, nB);
      addr = [NSString stringWithFormat:@"localhost:%d", nB.server.listenPort];
      [nA.server connectToAddress:addr];

      WAIT_WHILE([links count] < nextCount);
    }

    for (BNLink *link in links)
      GHAssertTrue(link.connection.isConnected,
        @"Connection should be established.");
  }

  // GHAssertTrue([links count] == 2 * [nodes count] * ([nodes count] - 1),
  //   @"Should have (2 * # nodes * # nodes) connections");
}

- (void) testCB_allSending {
  NSData *data;
  BNMessage *msg;
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];

  // Send data between conn pairs.
  for (BNNode *sendr in [nodes allValues]) {
    for (BNNode *recvr in [nodes allValues]) {
      if (sendr == recvr)
        continue;

      msg = [BNMessage messageWithContents:dict];
      msg.source = sendr.name;
      msg.destination = recvr.name;
      data = [msg.contents BSONRepresentation];

      @synchronized(expect) {
        [[expect valueForKey:recvr.name] addObject:data];
      }

      GHAssertTrue([sendr sendMessage:msg], @"Sending ok.");
    }
  }

}

- (void) testCC_allResponse {
  NSData *data;
  BNMessage *msg;
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Derp" forKey:@"Herp"];

  // Send data between conn pairs.
  for (BNNode *recvr in [nodes allValues]) {
    for (BNNode *sendr in [nodes allValues]) {
      if (sendr == recvr)
        continue;

      msg = [BNMessage messageWithContents:dict];
      msg.source = sendr.name;
      msg.destination = recvr.name;
      data = [msg.contents BSONRepresentation];

      @synchronized(expect) {
        [[expect valueForKey:recvr.name] addObject:data];
      }

      GHAssertTrue([sendr sendMessage:msg], @"Sending ok.");
    }
  }
}

- (void) testCD_allSimultaneous {
  NSData *data1, *data2;
  BNMessage *msg1, *msg2;
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];

  // Send data between conn pairs.
  for (BNNode *node1 in [nodes allValues]) {
    for (BNNode *node2 in [nodes allValues]) {
      if (node1 == node2)
        continue;

      msg1 = [BNMessage messageWithContents:dict];
      msg2 = [BNMessage messageWithContents:dict];
      msg1.source = node1.name;
      msg2.source = node2.name;
      msg1.destination = node2.name;
      msg2.destination = node1.name;
      data1 = [msg1.contents BSONRepresentation];
      data2 = [msg2.contents BSONRepresentation];

      @synchronized(expect) {
        [[expect valueForKey:node2.name] addObject:data1];
        [[expect valueForKey:node1.name] addObject:data2];
      }
      GHAssertTrue([node1 sendMessage:msg1], @"Sending ok.");
      GHAssertTrue([node2 sendMessage:msg2], @"Sending ok.");
    }
    [self waitForAllExpected];
  }
}

- (void) testCE_allMultiple {

  NSData *data1, *data2;
  BNMessage *msg1, *msg2;
  NSDictionary *dict1, *dict2;

  for (int j = 0; j < 10; j++) {
    dict1 = [NSDictionary randomDictionary];
    dict2 = [NSDictionary randomDictionary];
    // Send data between conn pairs.
    for (BNNode *node1 in [nodes allValues]) {
      for (BNNode *node2 in [nodes allValues]) {
        if (node1 == node2)
          continue;

        msg1 = [BNMessage messageWithContents:dict1];
        msg2 = [BNMessage messageWithContents:dict2];
        msg1.source = node1.name;
        msg1.destination = node2.name;
        msg2.source = node2.name;
        msg2.destination = node1.name;
        data1 = [msg1.contents BSONRepresentation];
        data2 = [msg2.contents BSONRepresentation];

        @synchronized(expect) {
          [[expect valueForKey:node2.name] addObject:data1];
          [[expect valueForKey:node1.name] addObject:data2];
        }
        GHAssertTrue([node1 sendMessage:msg1], @"Sending ok.");
        GHAssertTrue([node2 sendMessage:msg2], @"Sending ok.");
      }
      [self waitForAllExpected];
    }
  }
}

- (void) testCF_allMultipleMultiple {

  for (int i = 0; i < 10; i++)
    [self testCE_allMultiple];

}

- (void) testCG_allDisconnect {

  if ([links count] == 0)
    [self testCA_allConnect];

  NSUInteger firstHalf = [links count] / 2;
  for (int i = 0; i < firstHalf; i += 2) { // every two.

    BNLink *link = [links objectAtIndex:i];
    [link disconnect];
  }

  WAIT_WHILE([links count] > firstHalf);
  GHAssertTrue([links count] == firstHalf, @"Should only have half now.");

  for (BNNode *node in [nodes allValues])
    [node disconnectLinks];

  WAIT_WHILE([links count] > 0);
  GHAssertTrue([links count] == 0, @"Should have none now.");
}

@end
