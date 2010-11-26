
#import <Foundation/Foundation.h>
#import "AsyncSocket.h"

@class BNConnection;
@class BNNetwork;

@protocol BNNetworkDelegate
- (void) network:(BNNetwork *)network error:(NSError *)error;
- (BOOL) network:(BNNetwork *)network shouldConnect:(BNConnection *)conn;
- (void) network:(BNNetwork *)network didConnect:(BNConnection *)conn;
- (void) network:(BNNetwork *)network failedConnect:(BNConnection *)conn
  withError:(NSError *)error;
@end

@interface BNNetwork <AsyncSocketDelegate> {

  UInt16 listenPort;
  AsyncSocket *listenSocket;
  NSThread *thread; // for socket thread safety

  NSMutableDictionary *connections;
  id<BNNetworkDelegate> delegate;
}

@property (nonatomic, assign) id<BNNetworkDelegate> delegate;
@property (nonatomic, readonly) UInt16 listenPort;

- (id) init;
- (id) initWithListenPort:(UInt16)port;

- (void) connectToAddress:(NSString *)address;
- (void) connectToAddresses:(NSArray *)addresses;
- (void) connectToOneAddress:(NSArray *)addresses; // NATs

- (void) disconnectFromAddress:(NSString *)address;
- (void) disconnectConnection:(BNConnection *)connection;
- (void) disconnectAllConnections;

@end
