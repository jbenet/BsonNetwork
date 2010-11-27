
#import <Foundation/Foundation.h>
#import "AsyncSocket.h"
#import "NuBSON.h"

typedef enum {
  BNConnectionDisconnected = 0,
  BNConnectionConnecting,
  BNConnectionConnected,
  BNConnectionDisconnecting,
  BNConnectionError,
} BNConnectionState;

typedef UInt16 BNMessageId;

@class BNConnection;

@protocol BNConnectionDelegate <NSObject>
- (void) connectionStateDidChange:(BNConnection *)conn;
- (void) connection:(BNConnection *)conn error:(NSError *)error;
@optional
- (void) connection:(BNConnection *)conn didTimeoutSending:(BNMessageId)msgId;
- (void) connection:(BNConnection *)conn didAcknowledge:(BNMessageId)msgId;
- (void) connection:(BNConnection *)conn receivedBSONData:(NSData *)bson;
- (void) connection:(BNConnection *)conn
  receivedDictionary:(NSDictionary *)dict;
@end

@interface BNConnection : NSObject <AsyncSocketDelegate> {

  UInt16 lastIdUsed;
  NSString *address;
  AsyncSocket *socket_;
  NSThread *thread_; // for socket thread safety
  NSMutableData *buffer;

  NSTimeInterval timeout;
  BNConnectionState state;
  id<BNConnectionDelegate> delegate;
}

@property (nonatomic, readonly) BNConnectionState state;
@property (nonatomic, readonly) NSString *address;

@property (nonatomic, assign) id<BNConnectionDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval timeout;

@property (nonatomic, readonly) BOOL isConnected;

- (id) initWithAddress:(NSString *)address;
- (id) initWithSocket:(AsyncSocket *)socket;

- (BOOL) connect; // returns whether connection is attempted. (AsyncSocket-like)
- (void) disconnect;

- (BNMessageId) sendDictionary:(NSDictionary *)dictionary;
- (BNMessageId) sendBSONData:(NSData *)data;

+ (void) extractHost:(NSString **)host andPort:(UInt16 *)port
  fromAddress:(NSString *)address;

- (NSString *) stateString;
+ (NSString *) stringForState:(BNConnectionState)state;

@end
