//
//  Part of BsonNetork
//
//  Created by Juan Batiz-Benet 2010.
//  MIT License, see LICENSE file for details.
//

#import "RandomObjects.h"

@implementation NSObject (RandomObjects)

+ (NSObject *) randomObject {
  int random = arc4random() % 25;
  switch (random) {
    case 0: return [NSNumber numberWithLong:arc4random() % 10000000];
    case 1:
    case 3: return [NSNumber numberWithInt:arc4random() % 10000];
    case 2: return [NSNumber numberWithFloat:(arc4random() % 10000) / 10000.0];
    case 4: return [NSNumber numberWithDouble:(arc4random() % 10000) / 10000.0];
    case 5:
    case 6: return [NSString randomStringOfLength:(arc4random() % 1000) + 1];
    case 8: return [NSDictionary randomDictionary];
    case 10: return [NSArray randomArray];
    case 11:
    case 12: return [NSNumber numberWithChar:arc4random() % 126];
    case 13: return [NSNumber numberWithBool:NO];
    case 14: return [NSNumber numberWithBool:YES];
    case 15:
    case 16: return [NSNumber numberWithShort:arc4random() % 1000];
    case 17:
    case 18: return [NSNumber numberWithShort:arc4random() % 1000];
    case 19:
    case 20: return [NSData dataWithBytes:"aBcDeFg" length:7];
  }
  return nil;
}

@end

@implementation NSString (RandomObjects)

+ (NSString *) randomStringOfLength:(int)length {
  NSMutableString *string = [NSMutableString string];
  for (int i = 0; i < length; i++)
    [string appendFormat:@"%d", arc4random() % 10];
  return string;
}

@end

@implementation NSArray (RandomObjects)

+ (NSArray *) randomArray {
  NSMutableArray *array = [[NSMutableArray alloc] init];
  NSObject *value = nil;
  do {
    value = [self randomObject];
    if (value)
      [array addObject:value];
  } while (value != nil);

  if ([array count] > 0)
    return [array autorelease];

  [array release];
  return [NSArray randomArray];
}

@end

@implementation NSDictionary (RandomObjects)

+ (NSDictionary *) randomDictionary {
  NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
  NSObject *value = nil;
  do {
    value = [self randomObject];
    [dict setValue:value forKey:[NSString randomStringOfLength:10]];
  } while (value != nil);

  if ([dict count] > 0)
    return [dict autorelease];

  [dict release];
  return [NSDictionary randomDictionary];
}

@end