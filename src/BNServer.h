
#import <Foundation/Foundation.h>
#import "AsyncSocket.h"
#import "BNConnection.h"

@class BNServer;

@protocol BNServerDelegate <NSObject>
- (void) server:(BNServer *)server error:(NSError *)error;
- (void) server:(BNServer *)server didConnect:(BNConnection *)conn;
- (void) server:(BNServer *)server failedToConnect:(BNConnection *)conn
  withError:(NSError *)error;
@optional
- (BOOL) server:(BNServer *)server shouldConnect:(BNConnection *)conn;
@end

@interface BNServer : NSObject <AsyncSocketDelegate, BNConnectionDelegate> {

  UInt16 listenPort;
  AsyncSocket *listenSocket_;

  NSThread *thread_; // for socket thread safety and not blocking main thread.
  NSMutableArray *connections_;

  id<BNServerDelegate> delegate;
}

@property (nonatomic, readonly) UInt16 listenPort;

@property (assign) id<BNServerDelegate> delegate;
@property (readonly) NSArray *connections;  // connected ones, that is.

- (id) init; // uses default listen port
- (id) initWithListenPort:(UInt16)port;

- (void) connectToAddress:(NSString *)address;
- (void) connectToAddresses:(NSArray *)addresses; // to all of them!

// To disconnect any one connection, simply call [connection disconnect].
// BNServer listens for BNConnectionDisconnectedNotifications.
- (void) disconnectAllConnections;

@end
