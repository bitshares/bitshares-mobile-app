//
//  ViewFormatConditons.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//  部分输入框文本格式条件显示视图。

#import <UIKit/UIKit.h>

@interface ViewFormatConditons : UIView

@property (nonatomic, assign) BOOL isAlwaysShow;     //  是否一直显示，默认为 NO。
@property (nonatomic, assign, readonly) BOOL isAllConditionsMatched;
@property (nonatomic, strong) NSString* lastCheckString;
@property (nonatomic, assign) CGFloat cellHeight;

/*
 *  (public) 快速添加条件 - 包含大写字母、小写字母、0-9的阿拉伯数字。
 */
- (void)fastConditionContainsUppercaseLetter:(NSString*)title;
- (void)fastConditionContainsLowercaseLetter:(NSString*)title;
- (void)fastConditionContainsArabicNumerals:(NSString*)title;
- (void)fastConditionBeginWithLetter:(NSString*)title;
- (void)fastConditionEndWithLetterOrDigit:(NSString*)title;
/*
 *  (public) 快速添加条件 - 包含2个以上非连续的大写字母。
 */
- (void)fastConditionContainsMoreThanTwoUppercaseLetterNonConsecutive:(NSString*)title;

/*
 *  (public) 添加条件 - 正则匹配类型。
 *  negative - 否定，表示不匹配。
 */
- (void)addRegularCondition:(NSString*)title regular:(NSString*)regular negative:(BOOL)negative;

/*
 *  (public) 添加条件 - 长度范围类型。区间范围 min..max。都是闭区间。
 *  negative - 否定，表示不匹配。
 */
- (void)addLengthCondition:(NSString*)title min_length:(NSInteger)min_length max_length:(NSInteger)max_length negative:(BOOL)negative;

/*
 *  (public) 触发器 - 文字变更检测。
 */
- (void)onTextDidChange:(NSString*)new_string;

/*
 *  (public) 重新计算尺寸。
 */
- (void)resizeFrame:(CGFloat)offsetX offsetY:(CGFloat)offsetY width:(CGFloat)width;

@end
