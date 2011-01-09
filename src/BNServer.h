//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import <Foundation/Foundation.h>
#import "AsyncSocket.h"
#import "BNConnection.h"
#import "PortMapper.h"

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

  PortMapper* mapper_;
  AsyncSocket *listenSocket_;

  NSThread *thread_; // for socket thread safety and not blocking main thread.
  NSMutableArray *connections_;

  id<BNServerDelegate> delegate;
  BOOL portMappingEnabled;
  UInt16 listenPort;
  BOOL isListening;
}

@property (nonatomic) BOOL portMappingEnabled;
@property (nonatomic, readonly) NSString *mappedAddress;

@property (nonatomic, readonly) UInt16 listenPort;
@property (nonatomic, readonly) BOOL isListening;

@property (assign) id<BNServerDelegate> delegate;
@property (readonly) NSArray *connections;  // connected ones, that is.

// using default listen port:
- (id) init; // with Current thread;
- (id) initWithThread:(NSThread *)thread;

- (BOOL) startListening;
- (BOOL) startListeningOnPort:(UInt16)_listenPorr;
- (void) stopListening;

- (void) connectToAddress:(NSString *)address;
- (void) connectToAddresses:(NSArray *)addresses; // to all of them!

// To disconnect any one connection, simply call [connection disconnect].
// BNServer listens for BNConnectionDisconnectedNotifications.
- (void) disconnectAllConnections;

@end
