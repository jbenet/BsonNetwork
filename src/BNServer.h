
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
  BOOL isListening;
}

@property (nonatomic, readonly) UInt16 listenPort;
@property (nonatomic, readonly) BOOL isListening;

@property (assign) id<BNServerDelegate> delegate;
@property (readonly) NSArray *connections;  // connected ones, that is.

- (id) init; // uses default listen port

- (BOOL) startListeningError:(NSError **)error;
- (BOOL) startListeningOnPort:(UInt16)_listenPort error:(NSError **)error;
- (void) stopListening;

- (void) connectToAddress:(NSString *)address;
- (void) connectToAddresses:(NSArray *)addresses; // to all of them!

// To disconnect any one connection, simply call [connection disconnect].
// BNServer listens for BNConnectionDisconnectedNotifications.
- (void) disconnectAllConnections;

@end
