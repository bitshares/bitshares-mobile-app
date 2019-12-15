//
//  ViewUtils.h
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import <Foundation/Foundation.h>

@interface ViewUtils : NSObject

/*
 *  (public) 辅助方法 - 生成Label。
 */
+ (UILabel*)auxGenLabel:(UIFont*)font superview:(UIView*)superview;

/*
 *  (public) 辅助计算文字尺寸
 */
+ (CGSize)auxSizeWithText:(NSString*)text font:(UIFont*)font maxsize:(CGSize)maxsize;
+ (CGSize)auxSizeWithText:(NSString*)text font:(UIFont*)font;
+ (CGSize)auxSizeWithLabel:(UILabel*)label maxsize:(CGSize)maxsize;
+ (CGSize)auxSizeWithLabel:(UILabel*)label;

/*
 *  (public) 辅助着色
 */
+ (NSMutableAttributedString*)genAndColorAttributedText:(NSString*)titleString
                                                  value:(NSString*)valueString
                                             titleColor:(UIColor*)titleColor
                                             valueColor:(UIColor*)valueColor;

/*
 *  (public) 大部分输入框占位符默认属性字符串
 */
+ (NSAttributedString*)placeholderAttrString:(NSString*)placeholder;
+ (NSAttributedString*)placeholderAttrString:(NSString*)placeholder font:(UIFont*)font color:(UIColor*)color;

@end
