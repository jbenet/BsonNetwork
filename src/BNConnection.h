//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import <Foundation/Foundation.h>
#import "AsyncSocket.h"
#import <bson-objc/BSONCodec.h>

typedef enum {
  BNConnectionDisconnected = 0,
  BNConnectionConnecting,
  BNConnectionConnected,
  BNConnectionDisconnecting,
  BNConnectionError,
} BNConnectionState;

// Notification fo connection managers (like BNServer)
extern NSString * const BNConnectionDisconnectedNotification;
extern NSString * const BNConnectionConnectedNotification;

typedef UInt16 BNMessageId;

@class BNConnection;

@protocol BNConnectionDelegate <NSObject>
- (void) connection:(BNConnection *)conn error:(NSError *)error;
- (void) connectionStateDidChange:(BNConnection *)conn;
@optional
// Unused:
// - (void) connection:(BNConnection *)conn didTimeoutSending:(BNMessageId)msgId;
// - (void) connection:(BNConnection *)conn didAcknowledge:(BNMessageId)msgId;

- (void) connection:(BNConnection *)conn receivedBSONData:(NSData *)bson;
- (void) connection:(BNConnection *)conn
  receivedDictionary:(NSDictionary *)dict;
@end

@interface BNConnection : NSObject <AsyncSocketDelegate> {

  UInt16 lastIdUsed;
  NSString *address;
  AsyncSocket *socket_;
  NSThread *thread_; // for socket thread safety
  NSMutableData *buffer_;

  NSTimeInterval timeout;
  BNConnectionState state;
  id<BNConnectionDelegate> delegate;
}

@property (nonatomic, readonly) BNConnectionState state;
@property (nonatomic, readonly) NSString *address; // address inited with.

@property (nonatomic, readonly) UInt16 localPort;
@property (nonatomic, readonly) NSString *localAddress;
@property (nonatomic, readonly) NSString *localHost;

@property (nonatomic, readonly) UInt16 connectedPort;
@property (nonatomic, readonly) NSString *connectedAddress;
@property (nonatomic, readonly) NSString *connectedHost;

@property (nonatomic, assign) id<BNConnectionDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval timeout;

@property (nonatomic, readonly) BOOL isConnected;

- (id) initWithAddress:(NSString *)address;
- (id) initWithSocket:(AsyncSocket *)socket;

- (BOOL) connect; // returns whether connection is attempted. (AsyncSocket-like)
- (void) disconnect;

- (BNMessageId) sendDictionary:(NSDictionary *)dictionary;
- (BNMessageId) sendBSONData:(NSData *)data;

+ (NSString *) addressWithHost:(NSString *)host andPort:(UInt16)port;
+ (void) extractHost:(NSString **)host andPort:(UInt16 *)port
  fromAddress:(NSString *)address;

- (NSString *) stateString;
+ (NSString *) stringForState:(BNConnectionState)state;

@end
