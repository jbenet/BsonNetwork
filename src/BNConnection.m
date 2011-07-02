//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BNConnection.h"
#import "AsyncSocket.h"
#import "platform_hacks.h"

static NSTimeInterval kDEFAULT_TIMEOUT = -1;

NSString * const BNConnectionDisconnectedNotification =
  @"BNConnectionDisconnected";
NSString * const BNConnectionConnectedNotification =
  @"BNConnectionConnected";

#pragma mark BSON Utils

static inline int __lengthOfFirstBSONDocument(NSData *data) {
  int length;
  const void *bytes = [data bytes];
  bson_little_endian32(&length, bytes);
  return length;
}

static inline BOOL __dataContainsWholeDocument(NSData *data) {
  if ([data length] < 4)
    return NO;
  return __lengthOfFirstBSONDocument(data) <= [data length];
}

@implementation BNConnection

@synthesize delegate;
@synthesize timeout;
@synthesize address;
@synthesize state;

#pragma mark Initialization

- (id) init {
  [NSException raise:@"BNConnectionInitError"
    format:@"Connection initialized without address or socket."];
  return nil;
}

- (id) initWithSocket:(AsyncSocket *)_socket {
  if ((self = [super init])) {
    NSAssert(_socket != nil, @"Given socket must not be nil.");
    socket_ = [_socket retain];

    address = nil; // will get set by connection.
    thread_ = [NSThread currentThread];

    NSAssert([socket_ canSafelySetDelegate], @"Ensure delegate is ok.");
    socket_.delegate = self;
    [socket_ moveToRunLoop:[NSRunLoop currentRunLoop]]; // idempotent + asserts.

    timeout = kDEFAULT_TIMEOUT;
    state = socket_.isConnected ? BNConnectionConnected :BNConnectionConnecting;
    buffer_ = [[NSMutableData alloc] init];
    lastIdUsed = 0;
  }
  return self;
}

- (id) initWithAddress:(NSString *)_address {
  if ((self = [super init])) {
    address = [_address copy];
    thread_ = [NSThread currentThread];
    socket_ = [[AsyncSocket alloc] initWithDelegate:self];
    timeout = kDEFAULT_TIMEOUT;
    state = BNConnectionDisconnected;
    buffer_ = [[NSMutableData alloc] init];
    lastIdUsed = 0;
  }
  return self;
}

- (void) dealloc {
  [socket_ setDelegate:nil];
  [socket_ disconnect];
  [socket_ release];

  [address release];
  [buffer_ release];
  buffer_ = nil;
  [super dealloc];
}

//------------------------------------------------------------------------------
#pragma mark BNConnection connect

- (void) __safeConnect:(NSMutableArray *)array {
  NSString *host = nil;
  UInt16 port = 0;
  [[self class] extractHost:&host andPort:&port fromAddress:address];

  socket_.delegate = self;
  NSError *e = nil;
  if (![socket_ connectToHost:host onPort:port withTimeout:timeout error:&e]) {
    [delegate connection:self error:e];
    [array addObject:[NSNumber numberWithBool:NO]];
  } else {
    [array addObject:[NSNumber numberWithBool:YES]];
  }
}

- (BOOL) connect {
  if (state == BNConnectionConnected || state == BNConnectionConnecting)
    return YES;
  if (state == BNConnectionDisconnecting)
    return NO;

  NSMutableArray *array = [NSMutableArray array];

  if ([NSThread currentThread] != thread_)
    [self performSelector:@selector(__safeConnect:) onThread:thread_
      withObject:array waitUntilDone:YES];
  else
    [self __safeConnect:array];

  BOOL success = [[array objectAtIndex:0] boolValue];

  if (success) {
    state = BNConnectionConnecting;
    [delegate connectionStateDidChange:self];
  }

  return success;
}

- (void) disconnect {
  if (state == BNConnectionDisconnected)
    return;

  state = BNConnectionDisconnecting;
  [delegate connectionStateDidChange:self];

  [socket_ performSelector:@selector(disconnect) onThread:thread_
    withObject:nil waitUntilDone:YES];
}

- (BOOL) isConnected {
  return state == BNConnectionConnected;
}

//------------------------------------------------------------------------------
#pragma mark BNConnection Sending

- (void) __safeSendBSONData:(NSMutableArray *)array {
  if (state == BNConnectionDisconnected || state == BNConnectionDisconnecting) {
    [array addObject:[NSNumber numberWithLong:0]];
    return; // cannot send. disconnected.
  }

  NSData *data = [array objectAtIndex:0];
  // NSLog(@"Sending: %@", data);
  [socket_ writeData:data withTimeout:timeout tag:1];
  [array addObject:[NSNumber numberWithLong:++lastIdUsed]];
}

- (BNMessageId) sendBSONData:(NSData *)data {
  NSMutableArray *array = [NSMutableArray arrayWithObject:data];

  if ([NSThread currentThread] != thread_)
    [self performSelector:@selector(__safeSendBSONData:) onThread:thread_
      withObject:array waitUntilDone:YES];
  else
    [self __safeSendBSONData:array];

  return [[array objectAtIndex:1] longValue];
}

- (BNMessageId) sendDictionary:(NSDictionary *)dictionary {
  return [self sendBSONData:[dictionary BSONRepresentation]];
}


//------------------------------------------------------------------------------
#pragma mark Address Accessors

- (NSString *) localAddress {
  return [[self class] addressWithHost:[socket_ localHost]
    andPort:[socket_ localPort]];
}

- (NSString *) connectedAddress {
  return [[self class] addressWithHost:[socket_ connectedHost]
    andPort:[socket_ connectedPort]];
}

- (NSString *) connectedHost {
  return [socket_ connectedHost];
}
- (UInt16) connectedPort {
  return [socket_ connectedPort];
}

- (NSString *) localHost {
  return [socket_ localHost];
}
- (UInt16) localPort {
  return [socket_ localPort];
}

//------------------------------------------------------------------------------
#pragma mark AsyncSocket Delegate

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err {
  state = BNConnectionDisconnecting;
  [delegate connectionStateDidChange:self];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock {
  state = BNConnectionDisconnected;
  [delegate connectionStateDidChange:self];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:BNConnectionDisconnectedNotification object:self];
  if (sock.delegate == self)
    sock.delegate = nil;
}

- (void) onSocket:(AsyncSocket *)lstn didAcceptNewSocket:(AsyncSocket *)sock {
  [NSException raise:@"BNConnectionSocketMisuse"
    format:@"Connection accepted a new socket. This should not happen."];
}

- (NSRunLoop *)onSocket:(AsyncSocket *)sock
  wantsRunLoopForNewSocket:(AsyncSocket *)newSocket {
  [NSException raise:@"BNConnectionSocketMisuse"
    format:@"Connection accepted a new socket. This should not happen."];
  return [NSRunLoop currentRunLoop];
}

- (BOOL) onSocketWillConnect:(AsyncSocket *)sock {
  if (socket_ == sock)
    return YES;

  [NSException raise:@"BNConnectionSocketMisuse"
    format:@"Connection will connect to other socket. This should not happen."];

  return NO;
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host
  port:(UInt16)port {

  if (address == nil)
    address = [[[self class] addressWithHost:host andPort:port] retain];

  state = BNConnectionConnected;
  [delegate connectionStateDidChange:self];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:BNConnectionConnectedNotification object:self];

  [socket_ readDataWithTimeout:timeout tag:1];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data
  withTag:(long)tag {
  if (!buffer_) {
    // NSLog(@"Connection without a buffer received data.");
    return;
  }

  [buffer_ appendData:data];

  if (__dataContainsWholeDocument(buffer_)) {
    // NSLog(@"Received: %@", data);
    NSRange docRange = NSMakeRange(0, __lengthOfFirstBSONDocument(buffer_));
    NSData *doc = [buffer_ subdataWithRange:docRange];
    if ([delegate respondsToSelector:@selector(connection:receivedBSONData:)])
      [delegate connection:self receivedBSONData:doc];
    if ([delegate respondsToSelector:@selector(connection:receivedDictionary:)])
      [delegate connection:self receivedDictionary:[doc BSONValue]];
    [buffer_ replaceBytesInRange:docRange withBytes:NULL length:0];
    tag = 1;
  }

  // [socket_ readDataToData:[AsyncSocket ZeroData] withTimeout:timeout tag:0];
  [socket_ readDataWithTimeout:timeout tag:tag];
}

//------------------------------------------------------------------------------
#pragma mark utils

+ (NSString *) addressWithHost:(NSString *)host andPort:(UInt16)port {
  return [NSString stringWithFormat:@"%@:%d", host, port];
}

+ (void) extractHost:(NSString **)host andPort:(UInt16 *)port
  fromAddress:(NSString *)address {
  NSCharacterSet *c = [NSCharacterSet characterSetWithCharactersInString:@":"];
  NSArray *operands = [address componentsSeparatedByCharactersInSet:c];

  if ([operands count] != 2)
    [NSException raise:@"BNConnectionBadAddress"
      format:@"BNConnection bad address format: %@", address];

  *host = [operands objectAtIndex:0];
  *port = [[operands objectAtIndex:1] intValue];
}

- (NSString *) stateString {
  return [BNConnection stringForState:state];
}

- (NSString *) description {
  NSString *st = [self stateString];
  return [NSString stringWithFormat:@"BNConnection to %@ (%@)", address, st];
}

+ (NSString *) stringForState:(BNConnectionState)state {
  switch (state) {
    case BNConnectionError: return @"Error";
    case BNConnectionConnected: return @"Connected";
    case BNConnectionConnecting: return @"Connecting";
    case BNConnectionDisconnected: return @"Disconnected";
    case BNConnectionDisconnecting: return @"Disconnecting";
  }
  return @"Unkown";
}

@end