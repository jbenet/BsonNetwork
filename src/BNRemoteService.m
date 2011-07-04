//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "BsonNetwork.h"

// Notifications Thrown:
NSString * const BNRemoteServiceReceivedMessageNotification =
  @"BNRemoteServiceReceivedMessageNotification";
NSString * const BNRemoteServiceSentMessageNotification =
  @"BNRemoteServiceSentMessageNotification";



@implementation BNRemoteService

@synthesize node, name, delegate, lastReceivedDate, lastReceivedMessage;

//------------------------------------------------------------------------------
#pragma mark Init/Dealloc

- (id) init {
  [NSException raise:@"BNRemoteServiceInitError"
    format:@"RemoteService requires a name and a node"];
  return nil;
}

- (id) initWithName:(NSString *)_name andNode:(BNNode *)_node {
  if ((self = [super init])) {

    name = [_name copy];
    node = [_node retain];

    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(__nodeReceivedMessageNotification:)
      name:BNNodeReceivedMessageNotification object:node];

    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(__nodeSentMessageNotification:)
      name:BNNodeSentMessageNotification object:node];

  }
  return self;
}

- (void) dealloc {
  [node release];
  [name release];
  [lastReceivedDate release];
  [lastReceivedMessage release];
  [super dealloc];
}


//------------------------------------------------------------------------------

- (NSString *) description {
  return [NSString stringWithFormat:@"<BNRemoteService %@>", name];
}

//------------------------------------------------------------------------------
#pragma mark Messages

- (BOOL) sendMessage:(BNMessage *)message {

  if (!message.source)
    message.source = node.name;
  if (!message.destination)
    message.destination = name;

  return [node sendMessage:message];

}

- (BOOL) sendDictionary:(NSDictionary *)message {
  return [self sendMessage:[BNMessage messageWithContents:message]];
}

- (void) __nodeReceivedMessageNotification:(NSNotification *)notification {

  BNMessage * message = [notification.userInfo valueForKey:@"message"];
  if (!message || !message.source || ![message.source isEqualToString:name])
    return; // not for us.

  [lastReceivedMessage release];
  lastReceivedMessage = [message retain];

  [lastReceivedDate release];
  lastReceivedDate = [[NSDate date] retain];

  [delegate remoteService:self receivedMessage:message];

  [[NSNotificationCenter defaultCenter] postNotification:[NSNotification
    notificationWithName:BNRemoteServiceReceivedMessageNotification object:self
    userInfo:notification.userInfo]];
}

- (void) __nodeSentMessageNotification:(NSNotification *)notification {

  BNMessage * message = [notification.userInfo valueForKey:@"message"];
  if (!message || !message.destination ||
    ![message.destination isEqualToString:name])
    return; // not for us.

  if ([delegate respondsToSelector:@selector(remoteService:sentMessage:)])
    [delegate remoteService:self sentMessage:message];

  [[NSNotificationCenter defaultCenter] postNotification:[NSNotification
    notificationWithName:BNRemoteServiceSentMessageNotification object:self
    userInfo:notification.userInfo]];
}

@end

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
#pragma mark -


@implementation BNReliableRemoteService

#pragma mark Init/Dealloc

- (id) initWithName:(NSString *)_name andNode:(BNNode *)_node {
  if ((self = [super initWithName:_name andNode:_node])) {

    queue_ = [[BNMessageQueue alloc] init];

  }
  return self;
}

- (void) dealloc {
  [queue_ release];
  [super dealloc];
}



- (BOOL) sendMessage:(BNMessage *)message {

  [queue_ enqueueSendMessage:message];
  message = [queue_ dequeueSendMessage];
  if (message)
    [super sendMessage:message];

  return YES;
}


- (void) __nodeReceivedMessageNotification:(NSNotification *)notification {

  BNMessage * message = [notification.userInfo valueForKey:@"message"];
  if (!message || !message.source || ![message.source isEqualToString:name])
    return; // not for us.

  [queue_ enqueueRecvMessage:message];
  message = [queue_ dequeueRecvMessage];
  if (!message)
    return; // no message ready.

  [lastReceivedMessage release];
  lastReceivedMessage = [message retain];

  [lastReceivedDate release];
  lastReceivedDate = [[NSDate date] retain];

  [delegate remoteService:self receivedMessage:message];

  [[NSNotificationCenter defaultCenter] postNotification:[NSNotification
    notificationWithName:BNRemoteServiceReceivedMessageNotification object:self
    userInfo:notification.userInfo]];
}


@end

