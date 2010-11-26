
#import "BNConnection.h"

@interface BNConnectionTest : GHTestCase <BNConnectionDelegate> {
  AsyncSocket *listenSocket;
  NSMutableDictionary *connections;

  NSTimeInterval wait;
  NSData *expect;
}
@property (nonatomic, retain) NSData *expect;
@end

static NSString *kHOST1 = @"localhost:1338";
//static NSString *kHOST2 = @"localhost:1338";
//static NSString *kHOST3 = @"localhost:1339";


@implementation BNConnectionTest

@synthesize expect;

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
  [NSThread sleepForTimeInterval:0.5];
}

- (void)tearDown {
  [NSThread sleepForTimeInterval:0.5];

  GHAssertNil(self.expect, @"Must not be waiting for anything else.");
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

  // NSLog(@"conn: %@ received: %@", conn, dict);
  NSData *bson = [dict BSONRepresentation];

  if (expect)
    NSLog(@"Expecting: %d Received: %d", [expect length], [bson length]);

  if (expect && [expect isKindOfClass:[NSData class]])
    GHAssertTrue([expect isEqual:bson], @"Expected dictionary not received.");
  else
    GHAssertTrue(false, @"Unexpected dictionary received.");

  self.expect = nil;
}

- (void)testA_Connected {

  for (BNConnection *conn in [connections allValues])
    GHAssertTrue(conn.isConnected, @"Make sure connections are connected.");
}

- (void) testB_BounceSimpleDict {
  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:@"Herp" forKey:@"Derp"];

  self.expect = [dict BSONRepresentation];

  BNConnection *conn = [connections valueForKey:kHOST1];
  GHAssertTrue([conn sendDictionary:dict] > 0, @"Sending ok.");

}

- (void) testC_BounceLargeDict {

  NSString *path;
  path = [[NSBundle mainBundle] pathForResource:@"hamlet" ofType: @"txt"];
  NSString *hamlet = [NSString stringWithContentsOfFile:path
    encoding:NSUTF8StringEncoding error:NULL];

  NSDictionary *dict = [NSMutableDictionary dictionary];
  [dict setValue:[hamlet substringToIndex:2000] forKey:@"hamlet"];
  self.expect = [dict BSONRepresentation];

  BNConnection *conn = [connections valueForKey:kHOST1];
  GHAssertTrue([conn sendDictionary:dict] > 0, @"Sending ok.");
}

@end
