
#import <Foundation/Foundation.h>

@interface NSObject (RandomObjects)
+ (NSObject *) randomObject;
@end

@interface NSString (RandomObjects)
+ (NSString *) randomStringOfLength:(int)length;
@end

@interface NSArray (RandomObjects)
+ (NSArray *) randomArray;
@end

@interface NSDictionary (RandomObjects)
+ (NSDictionary *) randomDictionary;
@end