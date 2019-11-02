//
//  Extension.h
//  部分标准类方法扩展
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>

typedef BOOL (^ViewCallback)(UIView* view);

@interface UIView (Aux)

- (UIView*)findSubview:(Class)klass resursion:(BOOL)resursion;
- (BOOL)iterateSubview:(ViewCallback)handler;

@end

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

@interface NSString (BtsppExt)

/**
 *  URL 编码/解码
 */
- (NSString*)url_encode;

- (NSString*)url_decode;

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

typedef void (^RubyApplyBody)(id obj);
@interface NSObject (BtsppExt)

- (id)ruby_apply:(RubyApplyBody)func;

/*
 *  (public) 序列化为json字符串。
 */
- (id)to_json:(BOOL)as_data;
- (id)to_json;

@end
