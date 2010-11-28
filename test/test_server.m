
#import "BNServer.h"
#import "RandomObjects.h"

@interface BNServerTest : GHTestCase <BNConnectionDelegate, BNServerDelegate> {

  NSMutableArray *connections;
  NSMutableDictionary *servers;

  NSMutableDictionary *expect;

}

@end

static NSString *kHOST1 = @"localhost:1337";
static NSString *kHOST2 = @"localhost:1338";
static NSString *kHOST3 = @"localhost:1339";
static NSString *kHOST4 = @"localhost:1340";

@implementation BNServerTest

//------------------------------------------------------------------------------
#pragma mark setup

- (BOOL) shouldRunOnMainThread {
  return NO;
}

- (void) setupConnection:(NSString *)address {
  NSLog(@"Setting up server at %@", address);
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSString *host;
  UInt16 port;
  [BNConnection extractHost:&host andPort:&port fromAddress:address];

  BNServer *server = [[BNServer alloc] init];
  server.delegate = self;
  @synchronized(servers) {
    [servers setValue:server forKey:address];
  }

  GHAssertFalse(server.isListening, @"Server shouldn't be listening yet...");
  GHAssertTrue([server startListeningOnPort:port error:NULL],
    @"Should be able to begin listening.");

  [[NSRunLoop currentRunLoop] run];

  [pool release];
}

- (void) setUpClass {
  connections = [[NSMutableArray alloc] initWithCapacity:10];
  servers = [[NSMutableDictionary alloc] initWithCapacity:10];
  expect = [[NSMutableDictionary alloc] initWithCapacity:10];

  SEL setup = @selector(setupConnection:);
  [NSThread detachNewThreadSelector:setup toTarget:self withObject:kHOST1];
  [NSThread detachNewThreadSelector:setup toTarget:self withObject:kHOST2];
  [NSThread detachNewThreadSelector:setup toTarget:self withObject:kHOST3];
  [NSThread detachNewThreadSelector:setup toTarget:self withObject:kHOST4];

  for (int i = 0; [servers count] != 4 && i < 10000; i++)
    [NSThread sleepForTimeInterval:1.0]; // main thread apparently.
}

- (void) tearDownClass {
  [connections release];
  [servers release];
  [expect release];
}

- (void) setUp {
  [NSThread sleepForTimeInterval:0.3];
}

- (void) tearDown {
  [NSThread sleepForTimeInterval:0.3];

  GHAssertTrue([expect count] == 0, @"Must not be waiting for anything else.");
}

//------------------------------------------------------------------------------
#pragma mark server delegate

- (void) server:(BNServer *)server error:(NSError *)error {
  NSLog(@"Server: %@ error: %@", server, error);
}

- (void) server:(BNServer *)server didConnect:(BNConnection *)conn {
  NSLog(@"Server: %@ did connect: %@", server, conn);
  conn.delegate = self;
  @synchronized(connections) {
    [connections addObject:conn];
  }
}

- (void) server:(BNServer *)server failedToConnect:(BNConnection *)conn
  withError:(NSError *)error {
  NSLog(@"Server: %@ failed to connect: %@ error: %@", server, conn, error);
}

- (BOOL) server:(BNServer *)server shouldConnect:(BNConnection *)conn {
  NSLog(@"Server: %@ should connect: %@", server, conn);
  return YES;
}

//------------------------------------------------------------------------------
#pragma mark connection delegate

- (void) connectionStateDidChange:(BNConnection *)conn {
  NSLog(@"conn: %@ state: %d", conn, conn.state);
  switch (conn.state) {
    case BNConnectionConnected: break; // don't care... wont get it.
    case BNConnectionDisconnected:
      @synchronized(connections) {
        [connections removeObject:conn.address];
      }
      // No need to remove it; notification will take care of that.
      break;

    case BNConnectionConnecting: break; // don't care...
    case BNConnectionDisconnecting: break; // don't care...
    case BNConnectionError: break; // connection:error: should take care of it
  }
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

  NSString *expect_key = nil;
  @synchronized(connections) {
    int index = [connections indexOfObject:conn];
    expect_key = [NSString stringWithFormat:@"%d", index];
  }

  NSData *bson = [dict BSONRepresentation];
  NSData *ex_data = nil;
  @synchronized(expect) {
    ex_data = [expect valueForKey:expect_key];
  }

  NSLog(@"conn: %@ received. (%d==%d)", conn, [bson length], [ex_data length]);

  if (ex_data != nil && [ex_data isKindOfClass:[NSData class]])
    GHAssertTrue([ex_data isEqualToData:bson],
      @"Expected dictionary not received.");
  else
    GHAssertTrue(false, @"Unexpected dictionary received.");

  @synchronized(expect) {
    [expect setValue:nil forKey:expect_key];
  }
}

//------------------------------------------------------------------------------
#pragma mark helpers

- (void) forceWaitForExpected {
  for (int i = 0; [expect count] > 0 && i < 1000000; i++)
    [NSThread sleepForTimeInterval:1.0]; // main thread apparently.
}


//------------------------------------------------------------------------------
#pragma mark tests

- (void) testA_listening {
  for (BNServer *server in [servers allValues])
    GHAssertTrue(server.isListening, @"Should be listening now.");
}

- (void) testBA_simpleConnection {

  BNServer *serv1 = [servers valueForKey:kHOST1];
  [serv1 connectToAddress:kHOST2];

  for (int i = 0; [connections count] < 2 && i < 10000; i++)
    [NSThread sleepForTimeInterval:1.0]; // main thread apparently.

  BNConnection *conn1 = [connections objectAtIndex:0];
  BNConnection *conn2 = [connections objectAtIndex:1];
  GHAssertNotNil(conn1, @"Connection should be established.");
  GHAssertNotNil(conn2, @"Connection should be established.");
  // GHAssertEqualObjects(conn1.address, kHOST1, @"Addresses must match.");
  // GHAssertEqualObjects(conn2.address, kHOST2, @"Addresses must match.");
}

- (void) testBB_simpleSending {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];
  NSData *data = [dict BSONRepresentation];

  // Send data between conn1 <-> conn2.
  BNConnection *conn1 = [connections objectAtIndex:0];
  // BNConnection *conn2 = [connections objectAtIndex:1];
  @synchronized(expect) {
    [expect setValue:data forKey:[NSString stringWithFormat:@"%d", 1]];
  }
  GHAssertTrue([conn1 sendBSONData:data] > 0, @"Sending ok.");
}

- (void) testBC_simpleResponse {
   NSDictionary *dict = [NSMutableDictionary dictionary];
   [dict setValue:@"Derp" forKey:@"Herp"];
   NSData *data = [dict BSONRepresentation];

   // Send data between conn1 <-> conn2.
   // BNConnection *conn1 = [connections objectAtIndex:0];
   BNConnection *conn2 = [connections objectAtIndex:1];
   @synchronized(expect) {
     [expect setValue:data forKey:[NSString stringWithFormat:@"%d", 0]];
   }
   GHAssertTrue([conn2 sendBSONData:data] > 0, @"Sending ok.");
}

- (void) testBD_simpleSimultaneous {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];
  NSData *data = [dict BSONRepresentation];

  // Send data between conn1 <-> conn2.
  BNConnection *conn1 = [connections objectAtIndex:0];
  BNConnection *conn2 = [connections objectAtIndex:1];
  @synchronized(expect) {
    [expect setValue:data forKey:[NSString stringWithFormat:@"%d", 0]];
    [expect setValue:data forKey:[NSString stringWithFormat:@"%d", 1]];
  }
  GHAssertTrue([conn1 sendBSONData:data] > 0, @"Sending ok.");
  GHAssertTrue([conn2 sendBSONData:data] > 0, @"Sending ok.");
}

- (void) testBE_simpleMultiple {

  // Send data between conn1 <-> conn2.
  BNConnection *conn1 = [connections objectAtIndex:0];
  BNConnection *conn2 = [connections objectAtIndex:1];

  for (int i = 0; i < 10; i++) {
    NSData *data1 = [[NSDictionary randomDictionary] BSONRepresentation];
    NSData *data2 = [[NSDictionary randomDictionary] BSONRepresentation];
    @synchronized(expect) {
      [expect setValue:data1 forKey:[NSString stringWithFormat:@"%d", 0]];
      [expect setValue:data2 forKey:[NSString stringWithFormat:@"%d", 1]];
    }
    GHAssertTrue([conn1 sendBSONData:data2] > 0, @"Sending ok.");
    GHAssertTrue([conn2 sendBSONData:data1] > 0, @"Sending ok.");
    [self forceWaitForExpected];
  }
}

- (void) testBF_simpleMultipleMultiple {
  for (int i = 0; i < 10; i++)
    [self testBE_simpleMultiple];
}

@end
