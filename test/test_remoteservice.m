//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BNRemoteService.h"
#import "RandomObjects.h"

#ifndef WAIT_WHILE
#define WAIT_WHILE(condition) \
  for (int i = 0; (condition) && i < 10000; i++) \
    [NSThread sleepForTimeInterval:0.5]; // main thread apparently.
#endif

@interface BNRemoteServiceTest : GHTestCase <BNRemoteServiceDelegate> {

  NSMutableArray *services;
  NSMutableDictionary *expect;
  NSMutableDictionary *nodes;

}

@end

@implementation BNRemoteServiceTest

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
  UInt16 port = 1350 + num;

  BNNode *node = [[BNNode alloc] initWithName:name];
  @synchronized(nodes) {
    [nodes setValue:node forKey:name];
  }
  [node release];

  GHAssertFalse(node.server.isListening, @"shouldn't be listening yet...");
  GHAssertTrue([node.server startListeningOnPort:port],
    @"Should be able to begin listening.");

  [[NSRunLoop currentRunLoop] run];

  [pool release];
}

- (void) setUpClass {

  services = [[NSMutableArray alloc] initWithCapacity:10];
  expect = [[NSMutableDictionary alloc] initWithCapacity:10];
  nodes = [[NSMutableDictionary alloc] initWithCapacity:10];

  SEL setup = @selector(setupNodeWithNumber:);
  [NSThread detachNewThreadSelector:setup toTarget:self
    withObject:[NSNumber numberWithInt:1]];
  [NSThread detachNewThreadSelector:setup toTarget:self
    withObject:[NSNumber numberWithInt:2]];

  WAIT_WHILE([nodes count] < 2);

  BNRemoteService *rs;
  BNNode *node1 = [[nodes allValues] objectAtIndex:0];
  BNNode *node2 = [[nodes allValues] objectAtIndex:1];

  rs = [[BNRemoteService alloc] initWithName:node2.name andNode:node1];
  rs.delegate = self;
  [services addObject:rs];
  [rs release];

  rs = [[BNRemoteService alloc] initWithName:node1.name andNode:node2];
  rs.delegate = self;
  [services addObject:rs];
  [rs release];

  rs = [[BNRemoteService alloc] initWithName:@"node2bg" andNode:node1];
  rs.delegate = self;
  [services addObject:rs];
  [rs release];

  rs = [[BNRemoteService alloc] initWithName:@"node1bg" andNode:node2];
  rs.delegate = self;
  [services addObject:rs];
  [rs release];

}

- (void) tearDownClass {
  [services release];
  [expect release];
  [nodes release];

  services = nil;
  expect = nil;
  nodes = nil;
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
#pragma mark check in expect

- (BOOL) serviceNamed:(NSString *)name consumeExpectedData:(NSData *)data {
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

- (void) addExpectedData:(NSData *)data toServiceNamed:(NSString *)name {
  @synchronized(expect) {
    NSMutableArray *arr = [expect valueForKey:name];
    if (!arr) {
      arr = [NSMutableArray array];
      [expect setValue:arr forKey:name];
    }
    [arr addObject:data];
  }
}

//------------------------------------------------------------------------------
#pragma mark remote service delegate

- (void) remoteService:(BNRemoteService *)serv receivedMessage:(BNMessage *)msg
{
  NSData *data = [msg.contents BSONRepresentation];
  GHAssertTrue([serv.name isEqualToString:msg.source], @"name matching");
  GHAssertTrue([self serviceNamed:serv.node.name consumeExpectedData:data],
    @"data received.");
}

- (void) remoteService:(BNRemoteService *)serv error:(NSError *)error {
  NSLog(@"[%@] error %@", serv, error);
}

- (void) remoteService:(BNRemoteService *)serv sentMessage:(BNMessage *)msg {
  GHAssertTrue([serv.name isEqualToString:msg.destination], @"name matching");
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
  for (BNNode *node in [nodes allValues])
    GHAssertNil(node.defaultLink, @"Should be nil.");

  for (BNRemoteService *rs in services)
    GHAssertEqualObjects(rs.delegate, self, @"Should be equal.");
}

- (void) testAB_listening {
  for (BNNode *node in [nodes allValues])
    GHAssertTrue(node.server.isListening, @"Should be listening now.");
}

- (void) testBA_simpleConnect {

  BNNode *node1 = [nodes valueForKey:@"client1"];
  BNNode *node2 = [nodes valueForKey:@"client2"];
  [node1.server connectToAddress:@"localhost:1352"];

  WAIT_WHILE(![node1 linkForName:node2.name]);

  BNLink *l1 = [node1 linkForName:node2.name];
  BNLink *l2 = [node2 linkForName:node1.name];
  GHAssertNotNil(l1, @"Link should be established.");
  GHAssertNotNil(l2, @"Link should be established.");
  GHAssertNotNil(l1.connection, @"Connection should be established.");
  GHAssertNotNil(l2.connection, @"Connection should be established.");
  GHAssertTrue(l1.connection.isConnected, @"Connection should be established.");
  GHAssertTrue(l2.connection.isConnected, @"Connection should be established.");

  GHAssertTrue(
    ([l1.name isEqualToString:node2.name] &&
     [l2.name isEqualToString:node1.name]),
      @"Node names must match.");

}



- (void) testBB_simpleSending {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];

  BNRemoteService *rs = [services objectAtIndex:0];

  BNMessage *msg = [BNMessage messageWithContents:dict];
  msg.source = rs.node.name;
  msg.destination = rs.name;
  NSData *data = [msg.contents BSONRepresentation];

  [self addExpectedData:data toServiceNamed:rs.name];

  GHAssertTrue([rs sendMessage:msg], @"sending ok");
}


- (void) testBC_simpleResponse {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Derp" forKey:@"Herp"];

  BNRemoteService *rs = [services objectAtIndex:1];

  BNMessage *msg = [BNMessage messageWithContents:dict];
  msg.source = rs.node.name;
  msg.destination = rs.name;
  NSData *data = [msg.contents BSONRepresentation];

  [self addExpectedData:data toServiceNamed:rs.name];

  GHAssertTrue([rs sendMessage:msg], @"sending ok");
}

- (void) testBD_simpleSimultaneous {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Derp" forKey:@"Herp"];

  BNRemoteService *rs1 = [services objectAtIndex:0];
  BNRemoteService *rs2 = [services objectAtIndex:1];

  BNMessage *msg1 = [BNMessage messageWithContents:dict];
  msg1.source = rs1.node.name;
  msg1.destination = rs1.name;

  BNMessage *msg2 = [BNMessage messageWithContents:dict];
  msg2.source = rs2.node.name;
  msg2.destination = rs2.name;


  NSData *data1 = [msg1.contents BSONRepresentation];
  NSData *data2 = [msg2.contents BSONRepresentation];

  @synchronized(expect) {
    [self addExpectedData:data1 toServiceNamed:rs1.name];
    [self addExpectedData:data2 toServiceNamed:rs2.name];
  }

  GHAssertTrue([rs1 sendMessage:msg1], @"sending ok");
  GHAssertTrue([rs2 sendMessage:msg2], @"sending ok");
}

- (void) testBE_simpleMultiple {

  // Send data between conn1 <-> conn2.
  BNRemoteService *rs1 = [services objectAtIndex:0];
  BNRemoteService *rs2 = [services objectAtIndex:1];

  BNMessage *msg1 = nil;
  BNMessage *msg2 = nil;
  for (int i = 0; i < 10; i++) {
    msg1 = [BNMessage messageWithContents:[NSDictionary randomDictionary]];
    msg2 = [BNMessage messageWithContents:[NSDictionary randomDictionary]];

    msg1.source = rs1.node.name;
    msg1.destination = rs1.name;

    msg2.source = rs2.node.name;
    msg2.destination = rs2.name;

    NSData *data1 = [msg1.contents BSONRepresentation];
    NSData *data2 = [msg2.contents BSONRepresentation];

    @synchronized(expect) {
      [self addExpectedData:data1 toServiceNamed:rs1.name];
      [self addExpectedData:data2 toServiceNamed:rs2.name];
    }

    GHAssertTrue([rs1 sendMessage:msg1], @"Sending ok.");
    GHAssertTrue([rs2 sendMessage:msg2], @"Sending ok.");
    [self waitForAllExpected];
  }
}

- (void) testBF_simpleMultipleMultiple {
  for (int i = 0; i < 10; i++)
    [self testBE_simpleMultiple];
}

- (void) testBG_simpleDisconnect {

  if ([services count] == 0)
    [self testBA_simpleConnect];

  BNRemoteService *rs1 = [services objectAtIndex:0];
  BNRemoteService *rs2 = [services objectAtIndex:1];

  // BNConnection *conn2 = [connections objectAtIndex:1];
  [rs1.node disconnectLinks];
  [rs2.node disconnectLinks];

  WAIT_WHILE([rs1.node linkForName:rs1.name]);
  WAIT_WHILE([rs2.node linkForName:rs2.name]);

  GHAssertTrue([rs1.node linkForName:rs1.name] == nil, @"Should not have.");
  GHAssertTrue([rs2.node linkForName:rs2.name] == nil, @"Should not have.");
}


//
// - (void) testCA_allConnect {
//
//   [self testBA_simpleConnect];
//
// }
//
// - (void) testCB_allSending {
//
//   NSDictionary *dict = [NSMutableDictionary dictionary];
//   [dict setValue:@"Herp" forKey:@"Derp"];
//
//   for (BNRemoteService *rs in services) {
//
//     BNMessage *msg = [BNMessage messageWithContents:dict];
//     msg.source = rs.node.name;
//     msg.destination = rs.name;
//     NSData *data = [msg.contents BSONRepresentation];
//
//     [self addExpectedData:data toServiceNamed:rs.name];
//
//     GHAssertTrue([rs sendMessage:msg], @"sending ok");
//   }
//
// }
//
// - (void) testCC_allResponse {
//   NSDictionary *dict = [NSMutableDictionary dictionary];
//   [dict setValue:@"Derp" forKey:@"Herp"];
//
//   for (BNRemoteService *rs in services) {
//
//     BNMessage *msg = [BNMessage messageWithContents:dict];
//     msg.source = rs.node.name;
//     msg.destination = rs.name;
//     NSData *data = [msg.contents BSONRepresentation];
//
//     [self addExpectedData:data toServiceNamed:rs.name];
//
//     GHAssertTrue([rs sendMessage:msg], @"sending ok");
//   }
//
// }
//
// - (void) testCD_allSimultaneous {
//
//   NSDictionary *dict = [NSMutableDictionary dictionary];
//   [dict setValue:@"Derp" forKey:@"Herp"];
//
//   for (BNRemoteService *rs1 in services) {
//     for (BNRemoteService *rs2 in services) {
//       if (rs1 == rs2)
//         continue;
//
//       BNMessage *msg1 = [BNMessage messageWithContents:dict];
//       msg1.source = rs1.node.name;
//       msg1.destination = rs1.name;
//
//       BNMessage *msg2 = [BNMessage messageWithContents:dict];
//       msg2.source = rs2.node.name;
//       msg2.destination = rs2.name;
//
//
//       NSData *data1 = [msg1.contents BSONRepresentation];
//       NSData *data2 = [msg2.contents BSONRepresentation];
//
//       @synchronized(expect) {
//         [self addExpectedData:data1 toServiceNamed:rs1.name];
//         [self addExpectedData:data2 toServiceNamed:rs2.name];
//       }
//
//       GHAssertTrue([rs1 sendMessage:msg1], @"sending ok");
//       GHAssertTrue([rs2 sendMessage:msg2], @"sending ok");
//     }
//   }
// }
//
// - (void) testCE_allMultiple {
//
//   NSData *data1, *data2;
//   BNMessage *msg1, *msg2;
//   NSDictionary *dict1, *dict2;
//
//   for (int j = 0; j < 10; j++) {
//     dict1 = [NSDictionary randomDictionary];
//     dict2 = [NSDictionary randomDictionary];
//
//     for (BNRemoteService *rs1 in services) {
//       for (BNRemoteService *rs2 in services) {
//         if (rs1 == rs2)
//           continue;
//
//         msg1 = [BNMessage messageWithContents:dict1];
//         msg1.source = rs1.node.name;
//         msg1.destination = rs1.name;
//
//         msg2 = [BNMessage messageWithContents:dict2];
//         msg2.source = rs2.node.name;
//         msg2.destination = rs2.name;
//
//
//         data1 = [msg1.contents BSONRepresentation];
//         data2 = [msg2.contents BSONRepresentation];
//
//         @synchronized(expect) {
//           [self addExpectedData:data1 toServiceNamed:rs1.name];
//           [self addExpectedData:data2 toServiceNamed:rs2.name];
//         }
//
//         GHAssertTrue([rs1 sendMessage:msg1], @"sending ok");
//         GHAssertTrue([rs2 sendMessage:msg2], @"sending ok");
//       }
//     }
//     [self waitForAllExpected];
//   }
// }
//
// - (void) testCF_allMultipleMultiple {
//
//   for (int i = 0; i < 10; i++)
//     [self testCE_allMultiple];
//
// }
//
// - (void) testCG_allDisconnect {
//
//   [self testBG_simpleDisconnect];
//
// }

@end


@interface BNReliableRemoteServiceTest : BNRemoteServiceTest {}
@end

@implementation BNReliableRemoteServiceTest


- (BOOL) shouldRunOnMainThread {
  return NO;
}

- (void) setupNodeWithNumber:(NSNumber *)number {
  NSLog(@"Setting up node at %@", number);
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  int num = [number intValue];
  NSString *name = [NSString stringWithFormat:@"client%d", num];
  UInt16 port = 1350 + num;

  BNNode *node = [[BNNode alloc] initWithName:name];
  @synchronized(nodes) {
    [nodes setValue:node forKey:name];
  }
  [node release];

  GHAssertFalse(node.server.isListening, @"shouldn't be listening yet...");
  GHAssertTrue([node.server startListeningOnPort:port],
    @"Should be able to begin listening.");

  [[NSRunLoop currentRunLoop] run];

  [pool release];
}

- (void) setUpClass {

  services = [[NSMutableArray alloc] initWithCapacity:10];
  expect = [[NSMutableDictionary alloc] initWithCapacity:10];
  nodes = [[NSMutableDictionary alloc] initWithCapacity:10];

  SEL setup = @selector(setupNodeWithNumber:);
  [NSThread detachNewThreadSelector:setup toTarget:self
    withObject:[NSNumber numberWithInt:1]];
  [NSThread detachNewThreadSelector:setup toTarget:self
    withObject:[NSNumber numberWithInt:2]];

  WAIT_WHILE([nodes count] < 2);

  BNRemoteService *rs;
  BNNode *node1 = [[nodes allValues] objectAtIndex:0];
  BNNode *node2 = [[nodes allValues] objectAtIndex:1];

  rs = [[BNReliableRemoteService alloc] initWithName:node2.name andNode:node1];
  rs.delegate = self;
  [services addObject:rs];
  [rs release];

  rs = [[BNReliableRemoteService alloc] initWithName:node1.name andNode:node2];
  rs.delegate = self;
  [services addObject:rs];
  [rs release];

  rs = [[BNReliableRemoteService alloc] initWithName:@"node2bg" andNode:node1];
  rs.delegate = self;
  [services addObject:rs];
  [rs release];

  rs = [[BNReliableRemoteService alloc] initWithName:@"node1bg" andNode:node2];
  rs.delegate = self;
  [services addObject:rs];
  [rs release];
}



- (void) tearDownClass {
  [services release];
  [expect release];
  [nodes release];

  services = nil;
  expect = nil;
  nodes = nil;
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
#pragma mark check in expect

- (BOOL) serviceNamed:(NSString *)name consumeExpectedData:(NSData *)data {
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

- (void) addExpectedData:(NSData *)data toServiceNamed:(NSString *)name {
  @synchronized(expect) {
    NSMutableArray *arr = [expect valueForKey:name];
    if (!arr) {
      arr = [NSMutableArray array];
      [expect setValue:arr forKey:name];
    }
    [arr addObject:data];
  }
}

//------------------------------------------------------------------------------
#pragma mark remote service delegate

- (void) remoteService:(BNRemoteService *)serv receivedMessage:(BNMessage *)msg
{
  NSData *data = [msg.contents BSONRepresentation];
  GHAssertTrue([serv.name isEqualToString:msg.source], @"name matching");
  GHAssertTrue([self serviceNamed:serv.node.name consumeExpectedData:data],
    @"data received.");
}

- (void) remoteService:(BNRemoteService *)serv error:(NSError *)error {
  NSLog(@"[%@] error %@", serv, error);
}

- (void) remoteService:(BNRemoteService *)serv sentMessage:(BNMessage *)msg {
  GHAssertTrue([serv.name isEqualToString:msg.destination], @"name matching");
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
  for (BNNode *node in [nodes allValues])
    GHAssertNil(node.defaultLink, @"Should be nil.");

  for (BNRemoteService *rs in services)
    GHAssertEqualObjects(rs.delegate, self, @"Should be equal.");
}

- (void) testAB_listening {
  for (BNNode *node in [nodes allValues])
    GHAssertTrue(node.server.isListening, @"Should be listening now.");
}

- (void) testBA_simpleConnect {

  BNNode *node1 = [nodes valueForKey:@"client1"];
  BNNode *node2 = [nodes valueForKey:@"client2"];
  [node1.server connectToAddress:@"localhost:1352"];

  WAIT_WHILE(![node1 linkForName:node2.name]);

  BNLink *l1 = [node1 linkForName:node2.name];
  BNLink *l2 = [node2 linkForName:node1.name];
  GHAssertNotNil(l1, @"Link should be established.");
  GHAssertNotNil(l2, @"Link should be established.");
  GHAssertNotNil(l1.connection, @"Connection should be established.");
  GHAssertNotNil(l2.connection, @"Connection should be established.");
  GHAssertTrue(l1.connection.isConnected, @"Connection should be established.");
  GHAssertTrue(l2.connection.isConnected, @"Connection should be established.");

  GHAssertTrue(
    ([l1.name isEqualToString:node2.name] &&
     [l2.name isEqualToString:node1.name]),
      @"Node names must match.");

}



- (void) testBB_simpleSending {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];

  BNRemoteService *rs = [services objectAtIndex:0];

  BNMessage *msg = [BNMessage messageWithContents:dict];
  msg.source = rs.node.name;
  msg.destination = rs.name;
  NSData *data = [msg.contents BSONRepresentation];

  [self addExpectedData:data toServiceNamed:rs.name];

  GHAssertTrue([rs sendMessage:msg], @"sending ok");
}


- (void) testBC_simpleResponse {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Derp" forKey:@"Herp"];

  BNRemoteService *rs = [services objectAtIndex:1];

  BNMessage *msg = [BNMessage messageWithContents:dict];
  msg.source = rs.node.name;
  msg.destination = rs.name;
  NSData *data = [msg.contents BSONRepresentation];

  [self addExpectedData:data toServiceNamed:rs.name];

  GHAssertTrue([rs sendMessage:msg], @"sending ok");
}

- (void) testBD_simpleSimultaneous {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Derp" forKey:@"Herp"];

  BNRemoteService *rs1 = [services objectAtIndex:0];
  BNRemoteService *rs2 = [services objectAtIndex:1];

  BNMessage *msg1 = [BNMessage messageWithContents:dict];
  msg1.source = rs1.node.name;
  msg1.destination = rs1.name;

  BNMessage *msg2 = [BNMessage messageWithContents:dict];
  msg2.source = rs2.node.name;
  msg2.destination = rs2.name;


  NSData *data1 = [msg1.contents BSONRepresentation];
  NSData *data2 = [msg2.contents BSONRepresentation];

  @synchronized(expect) {
    [self addExpectedData:data1 toServiceNamed:rs1.name];
    [self addExpectedData:data2 toServiceNamed:rs2.name];
  }

  GHAssertTrue([rs1 sendMessage:msg1], @"sending ok");
  GHAssertTrue([rs2 sendMessage:msg2], @"sending ok");
}

- (void) testBE_simpleMultiple {

  // Send data between conn1 <-> conn2.
  BNRemoteService *rs1 = [services objectAtIndex:0];
  BNRemoteService *rs2 = [services objectAtIndex:1];

  BNMessage *msg1 = nil;
  BNMessage *msg2 = nil;
  for (int i = 0; i < 10; i++) {
    msg1 = [BNMessage messageWithContents:[NSDictionary randomDictionary]];
    msg2 = [BNMessage messageWithContents:[NSDictionary randomDictionary]];

    msg1.source = rs1.node.name;
    msg1.destination = rs1.name;

    msg2.source = rs2.node.name;
    msg2.destination = rs2.name;

    NSData *data1 = [msg1.contents BSONRepresentation];
    NSData *data2 = [msg2.contents BSONRepresentation];

    @synchronized(expect) {
      [self addExpectedData:data1 toServiceNamed:rs1.name];
      [self addExpectedData:data2 toServiceNamed:rs2.name];
    }

    GHAssertTrue([rs1 sendMessage:msg1], @"Sending ok.");
    GHAssertTrue([rs2 sendMessage:msg2], @"Sending ok.");
    [self waitForAllExpected];
  }
}

- (void) testBF_simpleMultipleMultiple {
  for (int i = 0; i < 10; i++)
    [self testBE_simpleMultiple];
}

- (void) testBG_simpleDisconnect {

  if ([services count] == 0)
    [self testBA_simpleConnect];

  BNRemoteService *rs1 = [services objectAtIndex:0];
  BNRemoteService *rs2 = [services objectAtIndex:1];

  // BNConnection *conn2 = [connections objectAtIndex:1];
  [rs1.node disconnectLinks];
  [rs2.node disconnectLinks];

  WAIT_WHILE([rs1.node linkForName:rs1.name]);
  WAIT_WHILE([rs2.node linkForName:rs2.name]);

  GHAssertTrue([rs1.node linkForName:rs1.name] == nil, @"Should not have.");
  GHAssertTrue([rs2.node linkForName:rs2.name] == nil, @"Should not have.");
}


@end
