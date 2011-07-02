//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BsonNetwork.h"
#import "PortMapper.h"

static UInt16 kDEFAULT_PORT = 31688;

static NSString *BNServerErrorDomain = @"BNServerErrorDomain";
typedef enum {
  BNErrorAsyncSocketFailed,
  BNErrorConnectionFailed,
  BNErrorUnknown,
} BNError;

@interface BNServer (Private)
- (void) __portMappingOpen;
+ (NSError *) error:(BNError)errorCode info:(NSString *)info;
@end

@implementation BNServer

@synthesize delegate, listenPort, isListening, portMappingEnabled;

//------------------------------------------------------------------------------
#pragma mark Init/Dealloc

- (id) init {
  return [self initWithThread:[NSThread currentThread]];
}

- (id) initWithThread:(NSThread *)_thread {
  if ((self = [super init])) {
    listenPort = kDEFAULT_PORT; // flag to say we're not listening...
    thread_ = _thread;

    connections_ = [[NSMutableArray alloc] initWithCapacity:10];

    listenSocket_ = [[AsyncSocket alloc] initWithDelegate:self];
    [listenSocket_ setRunLoopModes:
      [NSArray arrayWithObject:NSRunLoopCommonModes]];

    delegate = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(__connectionDisconnected:)
      name:BNConnectionDisconnectedNotification object:nil];

  }
  return self;
}

- (void) dealloc {
  if ([NSThread currentThread] != thread_) {
    [self performSelector:@selector(dealloc) onThread:thread_
      withObject:nil waitUntilDone:YES];
    return;
  }

  // Unmap
  [mapper_ release];

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
#pragma mark Listen Socket


- (BOOL) startListening {
  return [self startListeningOnPort:listenPort];
}

- (BOOL) startListeningOnPort:(UInt16)_listenPort {
  if (isListening && listenPort == _listenPort)
    return isListening;

  if (isListening)
    [self stopListening];

  listenPort = _listenPort;

  if ([NSThread currentThread] != thread_) {
    [self performSelector:@selector(startListening) onThread:thread_
      withObject:nil waitUntilDone:YES];
    return isListening;
  }

  NSError *error = nil;
  isListening = [listenSocket_ acceptOnPort:listenPort error:&error];
  if (isListening)
    listenPort = [listenSocket_ localPort]; // in case we used 0

  DebugLog(@"[%@] listening on port %d -- %d", self, listenPort, isListening);
  //TODO notifications? delegate calls?

  if (portMappingEnabled)
    [self __portMappingOpen];
  return isListening;
}

- (void) stopListening {
  if ([NSThread currentThread] != thread_) {
    [self performSelector:@selector(stopListening) onThread:thread_
      withObject:nil waitUntilDone:YES];
    return;
  }

  DebugLog(@"[%@] stop listening", self);
  //TODO notifications? delegate calls?
  isListening = NO;
  [mapper_ close]; //TODO(jbenet) perhaps dont close, to avoid others using it?
  [listenSocket_ disconnect];
}

- (BOOL) onSocketWillConnect:(AsyncSocket *)sock {
  DebugLog(@"[%@]", self);
  return YES;
}

- (void)onSocket:(AsyncSocket *)listn didAcceptNewSocket:(AsyncSocket *)socket {
  if (socket == nil)
    return;

  BNConnection *conn = [[BNConnection alloc] initWithSocket:socket];

  if (conn == nil) { // Odd. Conn is nil? are we thrashing around, or what?
    NSError *error = [BNServer error:BNErrorUnknown info:@"connection is nil"];
    [self.delegate server:self failedToConnect:conn withError:error];
    // [conn release]; it's nil! Added for appeasing OCDs.
    return;
  }

  @synchronized(connections_) {
    [connections_ addObject:conn];
  }

  conn.delegate = self;
  if (conn.isConnected) {
    conn.delegate = nil;
    [self.delegate server:self didConnect:conn];
  }

  DebugLog(@"[%@] accepted %@", self, conn);

  [conn release];
}

//------------------------------------------------------------------------------
#pragma mark Port Mapping

- (void) __portMappingOpen {
  if (!mapper_)
    mapper_ = [[PortMapper alloc] initWithPort:listenPort];

  mapper_.desiredPublicPort = listenPort;
  if ([mapper_ open]) {
    NSLog(@"[%@] requesting mapping for port %d", self, listenPort);

    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(__portMappingChanged:)
      name:PortMapperChangedNotification  object:mapper_];

  } else {
    NSLog(@"[%@] Error: PortMapper failed to start: %i", self, mapper_.error);
    [mapper_ release];
    mapper_ = nil;
  }
}

- (void) __portMappingChanged:(NSNotification*)notification {
  if (!mapper_) {
    NSLog(@"[%@] Received mapping notification without a mapper.", self);
    return;
  }

  if (mapper_.error) {
    NSLog(@"[%@] PortMapper error %i", self, mapper_.error);
    return;
  }

  NSLog(@"[%@] obtained public mapping at %@:%d", self,
    mapper_.publicAddress, mapper_.publicPort);
}

- (NSString *) mappedAddress {
  if (mapper_ == nil || mapper_.publicPort == 0)
    return nil;

  return [BNConnection addressWithHost:mapper_.publicAddress
    andPort:mapper_.publicPort];
}

- (void) setPortMappingEnabled:(BOOL)enabled {
  @synchronized(self) {
    if (enabled == portMappingEnabled)
      return; // idempotent...

    portMappingEnabled = enabled;

    [mapper_ release];
    mapper_ = nil;

    if (enabled && isListening) {
      mapper_ = [[PortMapper alloc] initWithPort:listenPort];
      [self __portMappingOpen];  // already listening! open it!
    }
  }
}

//------------------------------------------------------------------------------
#pragma mark Connect

- (void) connectToAddress:(NSString *)address {
  // Sanitize our input
  if (address == nil || ![address isKindOfClass:[NSString class]])
    return;

  // Ensure we initialize connections in our designated thread.
  if ([NSThread currentThread] != thread_) {
    [self performSelector:@selector(connectToAddress:) onThread:thread_
      withObject:address waitUntilDone:YES];
    return;
  }

  BNConnection *conn = [[BNConnection alloc] initWithAddress:address];
  conn.delegate = self; // for now, until connection is established.

  if (![conn connect]) { // could not even connect... AsyncSocket failed.
    DebugLog(@"[%@] failed to connect %@", self, conn);
    NSError *error = [BNServer error:BNErrorAsyncSocketFailed info:address];
    [self.delegate server:self failedToConnect:conn withError:error];
    [conn release];
    return;
  }

  if (conn == nil) { // Odd. Conn is nil? are we thrashing around, or what?
    DebugLog(@"[%@] failed to connect %@", self, conn);
    NSError *error = [BNServer error:BNErrorUnknown info:@"connection is nil"];
    [self.delegate server:self failedToConnect:conn withError:error];
    // [conn release]; it's nil! Added for appeasing OCDs.
    return;
  }

  @synchronized(connections_) {
    [connections_ addObject:conn];
  }

  DebugLog(@"[%@] connected %@", self, conn);

  [conn release];
}

- (void) connectToAddresses:(NSArray *)addresses {
  if (addresses == nil || ![addresses isKindOfClass:[NSArray class]])
    return;

  for (NSString *address in addresses)
    [self connectToAddress:address];
}

//------------------------------------------------------------------------------
#pragma mark Disconnect

- (void) disconnectAllConnections {
  if ([NSThread currentThread] != thread_) {
    [self performSelector:@selector(disconnectAllConnections) onThread:thread_
      withObject:nil waitUntilDone:YES];
    return;
  }

  DebugLog(@"[%@]", self);
  for (BNConnection *conn in self.connections) // copy for enumeration
    [conn disconnect];
}

//------------------------------------------------------------------------------
#pragma mark Notifications

- (void) __connectionDisconnected:(NSNotification *)notification {
  @synchronized(connections_) {
    [connections_ removeObject:[notification object]];
  }
}

//------------------------------------------------------------------------------
#pragma mark BNConnectionDelegate

- (void) connectionStateDidChange:(BNConnection *)conn {
  DebugLog(@"[%@] conn changed: %@", self, conn);

  switch (conn.state) {
    case BNConnectionConnected:
      conn.delegate = nil; // no longer us.
      [self.delegate server:self didConnect:conn];
      break;

    case BNConnectionDisconnected:
      // We got notified? must've failed.
      conn.delegate = nil;
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
  DebugLog(@"[%@] conn %@ error %@", self, conn, [error localizedDescription]);
  [self.delegate server:self error:error];
}


//------------------------------------------------------------------------------
#pragma mark Utils

- (NSString *) description {
  NSUInteger count = 0;
  @synchronized(connections_) {
    count = [connections_ count];
  }
  return [NSString stringWithFormat:@"BNServer:%d (%d"
    " connections)", listenPort, count];
}

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