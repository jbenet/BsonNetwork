//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BNConnection.h"
#import "RandomObjects.h"

#ifndef WAIT_WHILE
#define WAIT_WHILE(condition) \
  for (int i = 0; (condition) && i < 10000; i++) \
    [NSThread sleepForTimeInterval:0.5]; // main thread apparently.
#endif

@interface BNConnectionTest : GHTestCase <BNConnectionDelegate> {
  AsyncSocket *listenSocket;
  NSMutableDictionary *connections;

  NSTimeInterval wait;
  NSMutableDictionary *expect;

  NSString *lastToConnect;
  NSString *lastToDisconnect;
}

@end

// NOTE!!! to run these tests, run:
// % tests/bounce.py 1337
// % tests/bounce.py 1338
// % tests/bounce.py 1339
// % tests/bounce.py 1340

static NSString *kHOST1 = @"localhost:1337";
static NSString *kHOST2 = @"localhost:1338";
static NSString *kHOST3 = @"localhost:1339";
static NSString *kHOST4 = @"localhost:1340";


@implementation BNConnectionTest

//------------------------------------------------------------------------------
#pragma mark setup

- (BOOL)shouldRunOnMainThread {
  return NO;
}

- (void)setupConnection:(NSString *)address {
  NSLog(@"Setting up connection to %@", address);
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  BNConnection *conn = [[BNConnection alloc] initWithAddress:address];
  conn.delegate = self;
  [connections setValue:conn forKey:address];
  GHAssertTrue([conn connect], @"Connection Setup");

  [[NSRunLoop currentRunLoop] run];

  [conn release];
  [pool release];
}

- (void)setUpClass {
  connections = [[NSMutableDictionary alloc] initWithCapacity:10];
  expect = [[NSMutableDictionary alloc] initWithCapacity:10];

  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(connectionNotification:)
    name:BNConnectionDisconnectedNotification object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(connectionNotification:)
    name:BNConnectionConnectedNotification object:nil];

  SEL setup = @selector(setupConnection:);
  [NSThread detachNewThreadSelector:setup toTarget:self withObject:kHOST1];
  [NSThread detachNewThreadSelector:setup toTarget:self withObject:kHOST2];
  [NSThread detachNewThreadSelector:setup toTarget:self withObject:kHOST3];
  [NSThread detachNewThreadSelector:setup toTarget:self withObject:kHOST4];

}

- (void)tearDownClass {
  for (BNConnection *conn in [connections allValues])
    [conn disconnect];
  [connections release];
  [expect release];
}

- (void)setUp {
  [NSThread sleepForTimeInterval:0.3];
}

- (void)tearDown {
  [NSThread sleepForTimeInterval:0.3];

  GHAssertTrue([expect count] == 0, @"Must not be waiting for anything else.");
}


//------------------------------------------------------------------------------
#pragma mark connection delegate

- (void) connectionStateDidChange:(BNConnection *)conn {
  NSLog(@"conn: %@ state: %d", conn, conn.state);
}

- (void) connection:(BNConnection *)conn error:(NSError *)error {
  NSLog(@"conn: %@ error: %@", conn, [error localizedDescription]);
}

// - (void) connection:(BNConnection *)conn receivedBSONData:(NSData *)data {
//
//   NSLog(@"conn: %@ received: %@", conn, data);
//
//   // if (self.expect)
//   //   GHAssertEquals(self.expect, dict, @"Expected dictionary not received.");
//
// }

- (void) connection:(BNConnection *)conn
  receivedDictionary:(NSDictionary *)dict {

  NSData *bson = [dict BSONRepresentation];
  NSData *xdata = nil;

  @synchronized(expect) {
    xdata = [expect valueForKey:conn.address];
  }
  NSLog(@"conn: %@ received. (%lu==%lu)", conn, [bson length], [xdata length]);

  if (xdata != nil && [xdata isKindOfClass:[NSData class]])
    GHAssertTrue([xdata isEqualToData:bson],
      @"Expected dictionary not received.");
  else
    GHAssertTrue(false, @"Unexpected dictionary received.");

  @synchronized(expect) {
    [expect setValue:nil forKey:conn.address];
  }
}

//------------------------------------------------------------------------------
#pragma mark helpers

- (void) waitForAllExpected {
  WAIT_WHILE([expect count] > 0);
  GHAssertTrue([expect count] == 0, @"Should be expecting nothing else.");
}

- (void) connectionNotification:(NSNotification *)notification {
  NSLog(@"Received %@ notification.", notification);

  if ([notification name] == BNConnectionConnectedNotification)
    lastToConnect = [(BNConnection *)notification.object address];

  else if ([notification name] == BNConnectionDisconnectedNotification)
    lastToDisconnect = [(BNConnection *)notification.object address];
}

//------------------------------------------------------------------------------
#pragma mark tests

- (void)testA_Connected {

  for (BNConnection *conn in [connections allValues])
    GHAssertTrue(conn.isConnected, @"Make sure connections are connected.");
}

- (void) testB_BounceSimpleData {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];
  NSData *data = [dict BSONRepresentation];

  @synchronized(self) {
    [expect setValue:data forKey:kHOST1];
  }

  BNConnection *conn = [connections valueForKey:kHOST1];
  GHAssertTrue([conn sendBSONData:data] > 0, @"Sending ok.");

}

- (void) testC_BounceLargeData {
  NSString *path;
  path = [[NSBundle mainBundle] pathForResource:@"hamlet" ofType: @"txt"];
  NSString *hamlet = [NSString stringWithContentsOfFile:path
    encoding:NSUTF8StringEncoding error:NULL];

  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:hamlet forKey:@"hamlet"];
  NSData *data = [dict BSONRepresentation];

  @synchronized(self) {
    [expect setValue:data forKey:kHOST1];
  }
  BNConnection *conn = [connections valueForKey:kHOST1];
  GHAssertTrue([conn sendBSONData:data] > 0, @"Sending ok.");

  // Give it some extra time:
  [self waitForAllExpected];
}


- (void) testD_BounceSimpleDict {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];

  @synchronized(self) {
    [expect setValue:[dict BSONRepresentation] forKey:kHOST1];
  }
  BNConnection *conn = [connections valueForKey:kHOST1];
  GHAssertTrue([conn sendDictionary:dict] > 0, @"Sending ok.");

}

- (void) testE_BounceLargeDict {

  NSString *path;
  path = [[NSBundle mainBundle] pathForResource:@"hamlet" ofType: @"txt"];
  NSString *hamlet = [NSString stringWithContentsOfFile:path
    encoding:NSUTF8StringEncoding error:NULL];

  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:hamlet forKey:@"hamlet"];

  @synchronized(self) {
    [expect setValue:[dict BSONRepresentation] forKey:kHOST1];
  }
  BNConnection *conn = [connections valueForKey:kHOST1];
  GHAssertTrue([conn sendDictionary:dict] > 0, @"Sending ok.");

  // Give it some extra time:
  [self waitForAllExpected];
}

- (void) testF_BounceDataMultiple {

  NSData *data = [[NSDictionary randomDictionary] BSONRepresentation];
  @synchronized(expect) {
    [expect setValue:data forKey:kHOST1];
    [expect setValue:data forKey:kHOST2];
    [expect setValue:data forKey:kHOST3];
    [expect setValue:data forKey:kHOST4];
  }

  BNConnection *conn1 = [connections valueForKey:kHOST1];
  BNConnection *conn2 = [connections valueForKey:kHOST2];
  BNConnection *conn3 = [connections valueForKey:kHOST3];
  BNConnection *conn4 = [connections valueForKey:kHOST4];

  GHAssertTrue([conn1 sendBSONData:data] > 0, @"Sending ok.");
  GHAssertTrue([conn2 sendBSONData:data] > 0, @"Sending ok.");
  GHAssertTrue([conn3 sendBSONData:data] > 0, @"Sending ok.");
  GHAssertTrue([conn4 sendBSONData:data] > 0, @"Sending ok.");

}

- (void) testG_LongTest {

  for (int i = 0; i < 10; i++) {
    [self testF_BounceDataMultiple];
    [self waitForAllExpected];
  }
}

- (void) testH_ExtraLongTest {
  [self testG_LongTest];
  [self testG_LongTest];
  [self testG_LongTest];
  [self testG_LongTest];
  [self testG_LongTest];
  [self testG_LongTest];
  [self testG_LongTest];
  [self testG_LongTest];
}


- (void) testI_NotificationsTest {

  for (BNConnection *conn in [connections allValues]) {

    NSString *add = conn.address;

    [conn disconnect];
    WAIT_WHILE(![lastToDisconnect isEqualToString:add]);
    GHAssertTrue([lastToDisconnect isEqualToString:add],
      @"Last connection to disconnect is not correct.");

    [conn connect];

    WAIT_WHILE(![lastToConnect isEqualToString:add]);
    GHAssertTrue([lastToDisconnect isEqualToString:add],
      @"Last connection to connect is not correct.");
  }
}

//------------------------------------------------------------------------------

@end
