# BsonNetwork

## networking as easy as making a dictionary

BsonNetwork seeks to provide a very simple solution for application networking. Using the new [BSON standard](http://bsonspec.org/), BsonNetwork allows client applications to open connections and trade BSON documents (dictionaries!) around.

For now, BsonNetwork is only in Objective-C, enabling iPhones to talk to each other by trading NSDictionaries. I plan to add the (trivial) python implementation soon.

## Usage

BsonNetwork consists of two classes:

### BNServer

Use BNServer to manage and/or to listen for incoming connection, like so:

    BNServer *server = [[BNServer alloc] init];
    server.delegate = self;

    NSError *error = nil;
    [server startListeningOnPort:31688 error:&error];
    // Don't forget to check error values! :)

    [server connectToAddress:@"localhost:31688"];
    // yes, we can connect to ourselves

Then, when the BNConnection successfully connects, BNServer will call the delegate. Here we are greeting ourselves:

    - (void) server:(BNServer *)server didConnect:(BNConnection *)conn {

      conn.delegate = self; // From now on, we'll receive the messages.
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      [dict setValue:@"Hello World!" forKey:@"greeting"];
      [conn sendDictionary:dict];

    }

Note that BNServer will call @selector(server:didConnect:) for both incoming and outgoing connections.

### BNConnection

You can even use BNConnections without a BNServer:

    BNConnection *conn = [[BNConnection alloc] initWithAddress:@"localhost:31688"];
    conn.delegate = self;
    [conn connect];

And in turn, BNConnection will call its delegate when it changes state:

    - (void) connectionStateDidChange:(BNConnection *)conn {
      switch (conn.state) {
        case BNConnectionConnected:
          // we're connected!;
          break;

        case BNConnectionDisconnected:
          // Oh no, we disconnected!
          break;
      }
    }

And when it receives data:

    - (void) connection:(BNConnection *)conn receivedDictionary:(NSDictionary *)dict {
      if ([[dict valueForKey:@"greeting"] isEqualToString:@"Hello World!"]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Why Hello!\nWith love,\nThe World" forKey:@"response"];
        [conn sendDictionary:dict];
      }
    }

## Install

### Latest Release
-    download release/BsonNetwork.tar.gz and untar.
-    put BsonNetwork.framework* in your project.
-    add (existing apple framework) CFNetwork.framework to your project.

* Note: iPhone developers, do not worry. This .framework is not dynamically linked, it is a static library bundled as a framework for ease of use. I've already submitted apps with libraries bundled the same way. I'll update once BsonNetwork is live in an app.

### Building the Source
-    clone the repository
-    open the xcode project
-    select the Build Framework target
-    build for both Device Release and Simulator Release.

## License(s)

### BsonNetwork Licence

The BsonNetwork source is released under the MIT License, copyright 2010 Juan Batiz-Benet.
The source is available at [http://github.com/jbenet/bsonnetwork](http://github.com/jbenet/bsonnetwork)

### Libraries in use:

-   Martin Kou's BSONCodec. It is copyright 2010 Kou Man Tong. (MIT), available at [http://github.com/martinkou/bson-objc](http://github.com/martinkou/bson-objc)
-   cocoaasyncsocket, in the public domain, available at [http://code.google.com/p/cocoaasyncsocket/](http://code.google.com/p/cocoaasyncsocket/)

### Libraries that were being used, or will potentially be used:

-   The mongo-c-driver's C BSON source. It is copyright 2009, 2010 10gen Inc. (Apache 2.0), available at [http://github.com/mongodb/mongo-c-driver](http://github.com/mongodb/mongo-c-driver)
-   The ObjC NuBSON source. It is copyright 2010 Neon Design Technology, Inc. (Apache 2.0), available at [http://github.com/timburks/NuMongoDB](http://github.com/timburks/NuMongoDB)


## TODO:
-   Write usage examples and docs.
-   Write objc bounce test server using BNServer
-   Write python implementation.
-   Figure out why NuBSON sometimes fails to provide correct data. (Did key sorting break something?)