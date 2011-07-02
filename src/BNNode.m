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



NSString * const BNMessageSource = @"_src";
NSString * const BNMessageDestination = @"_dst";



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

    links_ = [[NSMutableDictionary alloc] initWithCapacity:10];
    defaultLink = nil;

  }
  return self;
}

- (void) dealloc {
  [self disconnectLinks];
  [links_ release];

  [server release];

  [name release];
  [super dealloc];
}


//------------------------------------------------------------------------------

- (BNLink *) linkForConnection:(BNConnection *)connection {
  for (BNLink * link in links_) {
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

  [[NSNotificationCenter defaultCenter] postNotification:[BNMessageNotification
    sentMessageNotificationWithNode:self link:link message:message]];

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

  switch (conn.state) {
    case BNConnectionConnected: break; // won't get.
    case BNConnectionDisconnected:

      link = [self linkForConnection:conn];
      nc = [NSNotificationCenter defaultCenter];
      [nc postNotificationName:BNNodeDisconnectedLinkNotification object:self
        userInfo:[NSDictionary dictionaryWithObject:link forKey:@"link"]];

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
    // Identified Link!
    if (link) { // old link?
      [nc postNotificationName:BNNodeDisconnectedLinkNotification object:self
        userInfo:[NSDictionary dictionaryWithObject:link forKey:@"link"]];
    }

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
    [nc postNotification:[BNMessageNotification
      receivedMessageNotificationWithNode:self link:link message:message]];

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

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark BNMessage

@implementation BNMessage

@synthesize contents;

- (id) init {
  if ((self = [super init])) {
    contents = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void) dealloc {
  [contents release];
  [super dealloc];
}

- (NSString *) source {
  return [contents valueForKey:BNMessageSource];
}

- (void) setSource:(NSString *)source {
  [contents setValue:source forKey:BNMessageSource];
}


- (NSString *) destination {
  return [contents valueForKey:BNMessageDestination];
}

- (void) setDestination:(NSString *)destination {
  [contents setValue:destination forKey:BNMessageDestination];
}

+ (BNMessage *) messageWithContents:(NSDictionary *)dictionary {
  BNMessage *msg = [[BNMessage alloc] init];
  [msg.contents addEntriesFromDictionary:dictionary];
  return [msg autorelease];
}

@end

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark BNMessageNotification

@implementation BNMessageNotification

@synthesize node, link, message;

+ (BNMessageNotification *) notificationWithName:(NSString *)name
  node:(BNNode *)node link:(BNLink *)link message:(BNMessage *) message
{
  BNMessageNotification *notification =
    [BNMessageNotification notificationWithName:name object:node];
  notification.node = node;
  notification.link = link;
  notification.message = message;
  return notification;
}

+ (BNMessageNotification *) sentMessageNotificationWithNode:(BNNode *)node
  link:(BNLink *)link message:(BNMessage *) message {
  return [self notificationWithName:BNNodeSentMessageNotification
    node:node link:link message:message];
}

+ (BNMessageNotification *) receivedMessageNotificationWithNode:(BNNode *)node
  link:(BNLink *)link message:(BNMessage *) message {
  return [self notificationWithName:BNNodeReceivedMessageNotification
    node:node link:link message:message];
}

@end

