//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BsonNetwork.h"

// Notifications Thrown:
NSString * const BNNodeConnectedLinkNotification =
  @"BNNodeConnectedLinkNotification";
NSString * const BNNodeIdentifiedLinkNotification =
  @"BNNodeIdentifiedLinkNotification";
NSString * const BNNodeDisconnectedLinkNotification =
  @"BNNodeDisconnectedLinkNotification";

NSString * const BNNodeReceivedMessageNotification =
  @"BNNodeReceivedMessageNotification";
NSString * const BNNodeSentMessageNotification =
  @"BNNodeSentMessageNotification";






@implementation BNNode

@synthesize name, server, delegate, defaultLink;

//------------------------------------------------------------------------------
#pragma mark Init/Dealloc

- (id) init {
  [NSException raise:@"BNNodeInitError" format:@"Node requires a name"];
  return nil;
}

- (id) initWithName:(NSString *)_name {
  return [self initWithName:_name andThread:[NSThread mainThread]];
}
- (id) initWithName:(NSString *)_name andThread:(NSThread *)thread {
  if ((self = [super init])) {

    name = [_name copy];
    server = [[BNServer alloc] initWithThread:thread];
    server.delegate = self;

    links_ = [[NSMutableDictionary alloc] initWithCapacity:10];
    defaultLink = nil;

  }
  return self;
}

- (void) dealloc {
  [self disconnectLinks];
  [links_ release];

  [server stopListening];
  [server release];

  [name release];
  [super dealloc];
}


//------------------------------------------------------------------------------

- (NSString *) description {
  return [NSString stringWithFormat:@"<Node %@>", name];
}

- (BNLink *) linkForConnection:(BNConnection *)connection {
  for (BNLink * link in [links_ allValues]) {
    if (link.connection == connection)
      return link;
  }
  return nil;
}

- (BNLink *) linkForName:(NSString *)linkName {
  return [links_ valueForKey:linkName];
}


- (void) disconnectLinks {
  NSArray *links = [links_ allValues];
  for (BNLink *link in links) {
    [link disconnect];
    [links_ setValue:nil forKey:link.name];
  }
}


- (BOOL) sendMessage:(BNMessage *)message {
  BNLink *link = [links_ valueForKey:message.destination];
  if (!link)
    link = defaultLink;

  if (!link)
    return NO;

  if (![link sendMessage:message])
    return NO;

  [[NSNotificationCenter defaultCenter] postNotification:[NSNotification
    notificationWithName:BNNodeSentMessageNotification object:self
    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:link, @"link",
    message, @"message", nil]]];

  return YES;
}


//------------------------------------------------------------------------------
#pragma mark BNServerDelegate

- (void) server:(BNServer *)server error:(NSError *)error {
  DebugLog(@"BNNode error: %@", error);

  [delegate node:self error:error];
}

- (void) server:(BNServer *)server didConnect:(BNConnection *)conn {
  DebugLog(@"BNNode connected to: %@", conn);

  conn.delegate = self;

  // identify self:
  BNMessage *message = [[BNMessage alloc] init];
  message.source = name;
  [conn sendDictionary:message.contents];
  [message release];
}

- (void) server:(BNServer *)server failedToConnect:(BNConnection *)conn
  withError:(NSError *)error {
  DebugLog(@"BNNode failedToConnect to: %@", conn);

  [delegate node:self error:error];
}


//------------------------------------------------------------------------------
#pragma mark BNConnectionDelegate

- (void) connectionStateDidChange:(BNConnection *)conn {
  DebugLog(@"[%@] conn changed: %@", self, conn);

  BNLink * link;
  NSNotificationCenter *nc;
  NSDictionary *userInfo = nil;

  switch (conn.state) {
    case BNConnectionConnected: break; // won't get.
    case BNConnectionDisconnected:

      link = [self linkForConnection:conn];
      if (link)
        userInfo = [NSDictionary dictionaryWithObject:link forKey:@"link"];

      nc = [NSNotificationCenter defaultCenter];
      [nc postNotificationName:BNNodeDisconnectedLinkNotification object:self
        userInfo:userInfo];

      [links_ setValue:nil forKey:link.name];
      break;

    case BNConnectionConnecting: break; // don't care...
    case BNConnectionDisconnecting: break; // don't care...
    case BNConnectionError: break; // connection:error: should take care of it
  }
}


- (void) connection:(BNConnection *)conn error:(NSError *)error {
  DebugLog(@"[%@] conn %@ error %@", self, conn, [error localizedDescription]);
  [self.delegate node:self error:error];
}


- (void) connection:(BNConnection *)conn
  receivedDictionary:(NSDictionary *)dict {
  DebugLog(@"[%@] conn %@ received %@", self, conn, dict);

  BNLink *link = [self linkForConnection:conn];
  NSString *source = [dict valueForKey:BNMessageSource];
  NSString *destination = [dict valueForKey:BNMessageDestination];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  if (source == nil) {
    DebugLog(@"[%@] malformed message", self);
    // DROP!
  }
  else if (destination == nil) {
    // Identified Link! (or re-identified.)

    link = [[BNLink alloc] initWithName:source andConnection:conn];
    [links_ setValue:link forKey:source];

    if (defaultLink == nil)
      defaultLink = link;

    DebugLog(@"[%@] identified link: %@", self, link);
    [nc postNotificationName:BNNodeConnectedLinkNotification object:self
      userInfo:[NSDictionary dictionaryWithObject:link forKey:@"link"]];


    [link release];
  }
  else if (link == nil) {
    // Message with a destination from an unidentified link.
    DebugLog(@"[%@] unidentified link sent message", self);
    // DROP!
  }
  else {
    // Got a message and have a link for it. notify!
    BNMessage *message = [BNMessage messageWithContents:dict];
    [nc postNotification:[NSNotification
      notificationWithName:BNNodeReceivedMessageNotification object:self
      userInfo: [NSDictionary dictionaryWithObjectsAndKeys:link, @"link",
      message, @"message", nil]]];

  }
}

@end

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark BNLink

@implementation BNLink

@synthesize name, connection;

- (id) init {
  [NSException raise:@"BNLinkInitError"
    format:@"Link requires a name and connection"];
  return nil;
}

- (id) initWithName:(NSString *)_name andConnection:(BNConnection *)conn {
  if ((self = [super init])) {
    name = [_name copy];
    connection = [conn retain];
  }
  return self;
}

- (void) dealloc {

  [name release];
  [connection release];
  [super dealloc];
}

- (void) disconnect {
  [connection disconnect];
}

- (BOOL) sendMessage:(BNMessage *)message {
  if (!connection.isConnected)
    return NO;

  [connection sendDictionary:message.contents];
  return YES;
}

@end

