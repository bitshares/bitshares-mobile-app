//
//  Extension.h
//  部分标准类方法扩展
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>

@interface NSNull (JSON)

@end

@interface NSData (Encoded)

/**
 *  16进制编码
 */
- (NSString*)hex_encode;

@end

//  TODO:fowallet 临时用，后期移除。
@interface NSDate (WQCalendarLogic)
+ (NSCalendar*)gregorianCalendar;
@end

@interface NSString (Format)

@end

typedef id (^RubyFilterMapFunction)(id src);
typedef BOOL (^RubyFilterBoolFunction)(id src);
typedef void (^RubyFilterEachWithIndexFunction)(id src, NSInteger idx);

@interface NSArray (RubyFilter)

- (void)ruby_each_with_index:(RubyFilterEachWithIndexFunction)func;
- (NSArray*)ruby_map:(RubyFilterMapFunction)func;
- (id)ruby_find:(RubyFilterBoolFunction)func;
- (NSArray*)ruby_select:(RubyFilterBoolFunction)func;
- (BOOL)ruby_all:(RubyFilterBoolFunction)func;
- (BOOL)ruby_any:(RubyFilterBoolFunction)func;

@end

@interface NSArray (SafeExt)

- (id)safeObjectAtIndex:(NSUInteger)index;

@end
