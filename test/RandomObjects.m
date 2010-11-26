
#import "RandomObjects.h"

@implementation NSObject (RandomObjects)

+ (NSObject *) randomObject {
  int random = arc4random() % 12;
  switch (random) {
    case 0:
    case 1:
    case 3: return [NSNumber numberWithInt:arc4random() % 10000];
    case 2:
    case 4: return [NSNumber numberWithDouble:(arc4random() % 10000) / 10000.0];
    case 5:
    case 6: return [NSString randomStringOfLength:(arc4random() % 1000) + 1];
    case 7: return [NSDictionary randomDictionary];
    case 8: return [NSArray randomArray];
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
  return [NSDictionary randomDictionary];
}

@end