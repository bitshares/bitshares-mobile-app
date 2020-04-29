//
//  Extension.h
//  部分标准类方法扩展
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>
#import "bts_wallet_core.h"

/*
 *  文字+图片 按钮的布局方式。
 */
typedef enum EUIButtonImageLayoutStyle
{
    ebils_top = 0,                  //  image在上，label在下
    ebils_left,                     //  image在左，label在右
    ebils_bottom,                   //  image在下，label在上
    ebils_right,                    //  image在右，label在左
} EUIButtonImageLayoutStyle;

typedef BOOL (^ViewCallback)(UIView* view);

@interface UIView (Aux)

- (UIView*)findSubview:(Class)klass resursion:(BOOL)resursion;
- (BOOL)iterateSubview:(ViewCallback)handler;

@end

@interface UIButton (Aux)

/*
 *  (public) 无动画更新UIButton中的标题文字。REMARK：UIButtonTypeSystem 风格的按钮更新文字默认会闪烁，而 UIButtonTypeCustom 风格按钮又没有点击动画。
 */
- (void)updateTitleWithoutAnimation:(NSString*)title;

/*
 *  (public) 重新排列标题文字和图片等布局方式。REMARK：仅同时存在文字和图片时候才需要用到。
 */
- (void)relayoutTitleImageStyle:(EUIButtonImageLayoutStyle)style space:(CGFloat)space;

@end

@interface NSNull (JSON)

@end

@interface NSData (Encoded)

/**
 *  16进制编码
 */
- (NSString*)hex_encode;

/*
 *  (public) 解码 base58 字符串
 */
- (NSString*)base58_encode;

/*
 *  (public) 解码 base58 字符串
 */
- (NSData*)base58_decode;

/*
 *  (public) AES256-CBC 加密/解密
 */
- (NSData*)aes256cbc_encrypt:(const digest_sha512*)secret;
- (NSData*)aes256cbc_decrypt:(const digest_sha512*)secret;

@end

@interface NSDate (WQCalendarLogic)

/*
 *  (public) 获取公历日历，不然日本等区域日历格式不同。
 */
+ (NSCalendar*)gregorianCalendar;

@end

@interface NSString (BtsppExt)

/*
 *  (public) 16进制编码/解码
 */
- (NSString*)hex_encode;
- (NSData*)hex_decode;

/*
 *  (public) 解码 base58 字符串
 */
- (NSData*)base58_decode;

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

@interface NSDictionary (SafeExt)

/*
 *  获取字符串，如果value不是字符串，则返回format后的值。
 */
- (id)optString:(id)aKey;

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
