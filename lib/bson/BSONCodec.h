//
//  BSONCodec.h
//  BSON Codec for Objective-C.
//
//  Created by Martin Kou on 8/17/10.
//  MIT License, see LICENSE file for details.
//

#import <Foundation/Foundation.h>
#import <stdint.h>

#define SWAP16(x) \
	((uint16_t)((((uint16_t)(x) & 0xff00) >> 8) | \
		(((uint16_t)(x) & 0x00ff) << 8)))

#define SWAP32(x) \
	((uint32_t)((((uint32_t)(x) & 0xff000000) >> 24) | \
		(((uint32_t)(x) & 0x00ff0000) >>  8) | \
		(((uint32_t)(x) & 0x0000ff00) <<  8) | \
		(((uint32_t)(x) & 0x000000ff) << 24)))

#define SWAP64(x) \
	((uint64_t)((((uint64_t)(x) & 0xff00000000000000ULL) >> 56) | \
		(((uint64_t)(x) & 0x00ff000000000000ULL) >> 40) | \
		(((uint64_t)(x) & 0x0000ff0000000000ULL) >> 24) | \
		(((uint64_t)(x) & 0x000000ff00000000ULL) >>  8) | \
		(((uint64_t)(x) & 0x00000000ff000000ULL) <<  8) | \
		(((uint64_t)(x) & 0x0000000000ff0000ULL) << 24) | \
		(((uint64_t)(x) & 0x000000000000ff00ULL) << 40) | \
		(((uint64_t)(x) & 0x00000000000000ffULL) << 56)))


#if BYTE_ORDER == LITTLE_ENDIAN
#define BSONTOHOST16(x) (x)
#define BSONTOHOST32(x) (x)
#define BSONTOHOST64(x) (x)
#define HOSTTOBSON16(x) (x)
#define HOSTTOBSON32(x) (x)
#define HOSTTOBSON64(x) (x)

#elif BYTE_ORDER == BIG_ENDIAN
#define BSONTOHOST16(x) SWAP16(x)
#define BSONTOHOST32(x) SWAP32(x)
#define BSONTOHOST64(x) SWAP64(x)
#define HOSTTOBSON16(x) SWAP16(x)
#define HOSTTOBSON32(x) SWAP16(x)
#define HOSTTOBSON64(x) SWAP16(x)

#endif

@protocol BSONCoding
- (uint8_t) BSONTypeID;
- (NSData *) BSONEncode;
- (NSData *) BSONRepresentation;
+ (id) BSONFragment: (NSData *) data at: (const void **) base ofType: (uint8_t) typeID;
@end

@protocol BSONObjectCoding
- (id) initWithBSONDictionary: (NSDictionary *) data;
- (NSDictionary *) BSONDictionary;
@end

@interface NSObject (BSONObjectCoding)
- (NSData *) BSONEncode;
- (NSData *) BSONRepresentation;
@end


@interface NSDictionary (BSON) <BSONCoding>
@end

@interface NSData (BSON) <BSONCoding>
- (NSDictionary *) BSONValue;
@end

@interface NSNumber (BSON) <BSONCoding>
@end

@interface NSString (BSON) <BSONCoding>
@end

@interface NSArray (BSON) <BSONCoding>
@end

@interface NSNull (BSON) <BSONCoding>
@end
