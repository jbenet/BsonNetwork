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

  [[NSNotificationCenter defaultCenter] removeObserver:self];

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


// @interface BNTimerExecution : NSObject {
//   NSObject *target;
//   SEL selector;
// }
// @property (nonatomic, assign) NSObject *target;
// @property (nonatomic, assign) SEL selector;
// - (void) execute:(NSTimer *)timer;
// + (BNTimerExecution *) executionWithTarget:(NSObject *)target selector:(SEL)sel;
// @end
//
// @implementation BNTimerExecution
//
// @synthesize target, selector;
//
// - (void) execute:(NSTimer *)timer {
//   NSLog(@"%@ FIRED", timer);
//   @synchronized(timer) {
//     [target performSelector:selector onThread:[NSThread currentThread]
//       withObject:nil waitUntilDone:YES];
//   }
// }
//
// + (BNTimerExecution *) executionWithTarget:(NSObject *)target selector:(SEL)sel
// {
//   BNTimerExecution *exec = [[BNTimerExecution alloc] init];
//   exec.target = target;
//   exec.selector = sel;
//   return [exec autorelease];
// }
// @end


@implementation BNReliableRemoteService

#pragma mark Init/Dealloc

- (id) initWithName:(NSString *)_name andNode:(BNNode *)_node {
  if ((self = [super initWithName:_name andNode:_node])) {

    queue_ = [[BNMessageQueue alloc] init];

//    BNTimerExecution *exec = [[BNTimerExecution alloc] init];
//    exec.target = self;
//    exec.selector = @selector(__periodicTimer);

    periodicTimer_ = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self
      selector:@selector(__periodicTimer) userInfo:nil repeats:YES];

//    [exec release];

    periodicTrickleTimeout_ = 0;
    nextTrickleTimeout_ = 1;
  }
  return self;
}

- (void) invalidateTimer {
  @synchronized(periodicTimer_) {
    [periodicTimer_ invalidate];
    periodicTimer_ = nil;
  }
}

- (void) dealloc {
  [self invalidateTimer];

  [queue_ release];
  [super dealloc];
}



- (BOOL) sendMessage:(BNMessage *)message {

  [queue_ enqueueSendMessage:message];
  message = [queue_ dequeueSendMessage];
  if (message)
    [super sendMessage:message];

  periodicTrickleTimeout_ = 0; // reset timer :)
  nextTrickleTimeout_ = 1;
  return YES;
}

- (void) __nodeReceivedMessageNotification:(NSNotification *)notification {

  BNMessage * message = [notification.userInfo valueForKey:@"message"];
  if (!message || !message.source || ![message.source isEqualToString:name])
    return; // not for us.

  if (message.seqNo != 0) { // got some data.
    nextTrickleTimeout_ = 1;
  }

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


- (void) __periodicTimer {
  static NSUInteger lastSeqNo = 0;

  BNMessage * message  = [queue_ dequeueSendMessage];
  if (!message)
    return;

  periodicTrickleTimeout_--;
  if (periodicTrickleTimeout_ > 0 && lastSeqNo > message.seqNo)
    return;

  lastSeqNo = message.seqNo;
  [super sendMessage:message];

  periodicTrickleTimeout_ = nextTrickleTimeout_;
  nextTrickleTimeout_ = MIN(nextTrickleTimeout_ * 2, 20);
}

- (id) retain {
  return [super retain];
}

- (void) release {
  [super release];
}

@end

