
#import "BNServer.h"

static UInt16 kDEFAULT_PORT = 31688;

static NSString *BNServerErrorDomain = @"BNServerErrorDomain";
typedef enum {
  BNErrorAsyncSocketFailed,
  BNErrorConnectionFailed,
  BNErrorUnknown,
} BNError;

@interface BNServer (Private)
+ (NSError *) error:(BNError)errorCode info:(NSString *)info;
@end

@implementation BNServer

@synthesize delegate, listenPort;

//------------------------------------------------------------------------------
#pragma mark Init/Dealloc

- (id) init {
  return [self initWithListenPort:kDEFAULT_PORT];
}

- (id) initWithListenPort:(UInt16)port {
  if (self = [super init]) {
    listenPort = port;
    thread_ = [NSThread currentThread];

    connections_ = [[NSMutableArray alloc] initWithCapacity:10];

    listenSocket_ = [[AsyncSocket alloc] initWithDelegate:self];
    delegate = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(__connectionDisconnected:)
      name:BNConnectionDisconnectedNotification object:nil];

  }
  return self;
}

- (void) dealloc {
  // stop accepting.
  [listenSocket_ setDelegate:nil];
  [listenSocket_ disconnect];
  [listenSocket_ release];

  // kill current connections.
  [self disconnectAllConnections];
  [connections_ release];

  [super dealloc];
}

//------------------------------------------------------------------------------
#pragma mark Connect

- (void) __connectToAddress:(NSString *)address withGroup:(NSString *)group {
  // Sanitize our input
  if (address == nil || ![address isKindOfClass:[NSString class]])
    return;

  BNConnection *conn = [[BNConnection alloc] initWithAddress:address];
  conn.delegate = self; // for now, until connection is established.

  if (![conn connect]) { // could not even connect... AsyncSocket failed.
    NSError *error = [BNServer error:BNErrorAsyncSocketFailed info:address];
    [self.delegate server:self failedToConnect:conn withError:error];
    [conn release];
    return;
  }

  if (conn == nil) { // Odd. Conn is nil? are we thrashing around, or what?
    NSError *error = [BNServer error:BNErrorUnknown info:@"connection is nil"];
    [self.delegate server:self failedToConnect:conn withError:error];
    // [conn release]; it's nil! Added for appeasing OCDs.
    return;
  }

  @synchronized(connections_) {
    [connections_ addObject:conn];
  }

  [conn release];
}

- (void) connectToAddress:(NSString *)address {
  [self __connectToAddress:address withGroup:nil];
}

- (void) connectToAddresses:(NSArray *)addresses {
  if (addresses == nil || ![addresses isKindOfClass:[NSArray class]])
    return;

  for (NSString *address in addresses)
    [self __connectToAddress:address withGroup:nil];
}

//------------------------------------------------------------------------------
#pragma mark Disconnect

- (void) disconnectAllConnections {
  for (BNConnection *conn in self.connections) // copy for enumeration
    [conn disconnect];
}

//------------------------------------------------------------------------------
#pragma mark Notifications

- (void) __connectionDisconnected:(NSNotification *)notification {
  @synchronized(connections_) {
    [connections_ removeObject:notification];
  }
}

//------------------------------------------------------------------------------
#pragma mark BNConnectionDelegate

- (void) connectionStateDidChange:(BNConnection *)conn {
  switch (conn.state) {
    case BNConnectionConnected:
      conn.delegate = nil; // no longer us.
      [self.delegate server:self didConnect:conn];
      break;

    case BNConnectionDisconnected:
      conn.delegate = nil; // We got notified? must've failed.
      NSError *err = [BNServer error:BNErrorConnectionFailed info:conn.address];
      [self.delegate server:self failedToConnect:conn withError:err];
      // No need to remove it; notification will take care of that.
      break;

    case BNConnectionConnecting: break; // don't care...
    case BNConnectionDisconnecting: break; // don't care...
    case BNConnectionError: break; // connection:error: should take care of it
  }
}

- (void) connection:(BNConnection *)conn error:(NSError *)error {
  [self.delegate server:self error:error];
}


//------------------------------------------------------------------------------
#pragma mark Utils

- (NSArray *) connections { // copy to prevent callers from mucking with us...
  @synchronized(connections_) {
    return [[connections_ copy] autorelease];
  }
}


+ (NSError *) error:(BNError)errorCode info:(NSString *)info {
  if (info == nil)
    info = @"Unknown";

  NSMutableString *infoFull = [NSMutableString string];
  switch (errorCode) {
    case BNErrorConnectionFailed:
      [infoFull appendFormat:@"Failed to connect to %@. (timed out?)", info];
      break;

    case BNErrorAsyncSocketFailed:
      [infoFull appendFormat:@"Failed to open socket to address: %@", info];
      break;

    case BNErrorUnknown:
      [infoFull appendFormat:@"Unknown error occurred: %@", info];
      break;

    default: [infoFull appendFormat:@"%@", info]; break;
  }

  NSDictionary *dict = [NSDictionary dictionaryWithObject:infoFull
    forKey:NSLocalizedDescriptionKey];

  return [NSError errorWithDomain:BNServerErrorDomain code:errorCode
    userInfo:dict];
}

@end