
#import "BNConnection.h"

@interface BNConnectionTest : GHTestCase <BNConnectionDelegate> {
  AsyncSocket *listenSocket;
  NSMutableDictionary *connections;

  NSTimeInterval wait;
  NSMutableDictionary *expect;
}

@end

static NSString *kHOST1 = @"localhost:1337";
static NSString *kHOST2 = @"localhost:1338";
static NSString *kHOST3 = @"localhost:1339";
static NSString *kHOST4 = @"localhost:1340";


@implementation BNConnectionTest

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

  [pool release];
}

- (void)setUpClass {
  connections = [[NSMutableDictionary alloc] initWithCapacity:10];
  expect = [[NSMutableDictionary alloc] initWithCapacity:10];

  SEL setup = @selector(setupConnection:);
  [NSThread detachNewThreadSelector:setup toTarget:self withObject:kHOST1];

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

  NSLog(@"conn: %@ received dict", conn, dict);
  NSData *bson = [dict BSONRepresentation];
  NSData *ex_data = [expect valueForKey:conn.address];

  if (ex_data && [ex_data isKindOfClass:[NSData class]])
    GHAssertTrue([ex_data isEqual:bson], @"Expected dictionary not received.");
  else
    GHAssertTrue(false, @"Unexpected dictionary received.");

  [expect setValue:nil forKey:conn.address];
}

- (void)testA_Connected {

  for (BNConnection *conn in [connections allValues])
    GHAssertTrue(conn.isConnected, @"Make sure connections are connected.");
}

- (void) testB_BounceSimpleDict {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];

  [expect setValue:[dict BSONRepresentation] forKey:kHOST1];

  BNConnection *conn = [connections valueForKey:kHOST1];
  GHAssertTrue([conn sendDictionary:dict] > 0, @"Sending ok.");

}

- (void) testC_BounceLargeDict {

  NSString *path;
  path = [[NSBundle mainBundle] pathForResource:@"hamlet" ofType: @"txt"];
  NSString *hamlet = [NSString stringWithContentsOfFile:path
    encoding:NSUTF8StringEncoding error:NULL];

  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:hamlet forKey:@"hamlet"];

  [expect setValue:[dict BSONRepresentation] forKey:kHOST1];
  BNConnection *conn = [connections valueForKey:kHOST1];
  GHAssertTrue([conn sendDictionary:dict] > 0, @"Sending ok.");

  for (int i; [expect valueForKey:kHOST1] && i < 1000000; i++)
    [NSThread sleepForTimeInterval:1.0];
}

- (void) testD_BounceMultiple {



}

@end
