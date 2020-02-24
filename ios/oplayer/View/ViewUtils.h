//
//  ViewUtils.h
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import <Foundation/Foundation.h>

@class UITableViewCellBase;
@class VerticalAlignmentLabel;

@interface ViewUtils : NSObject

/*
 *  (public) 辅助方法 - 生成 TableView 用的 CELL 视图对象。
 */
+ (UITableViewCellBase*)auxGenTableViewCellLine:(NSString*)title_string;
+ (UITableViewCellBase*)auxGenTableViewCellLine:(NSString*)title_string value:(NSString*)value_string;

/*
 *  (public) 辅助方法 - 生成Label。
 */
+ (UILabel*)auxGenLabel:(UIFont*)font superview:(UIView*)superview;
+ (VerticalAlignmentLabel*)auxGenVerLabel:(UIFont*)font;

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
