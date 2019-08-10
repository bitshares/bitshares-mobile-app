//
//  UITableViewCellBase.h
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import <UIKit/UIKit.h>

@interface UITableViewCellBase : UITableViewCell

@property (nonatomic, assign) BOOL showCustomBottomLine;                //  显示用户自定义下划线

@property (nonatomic, assign) BOOL disableDelayTouchesByAccessoryView;
@property (nonatomic, assign) BOOL hideBottomLine;                      //  系统CELL默认的横线
@property (nonatomic, assign) BOOL hideTopLine;                         //  系统CELL默认的横线

@property (nonatomic, assign) BOOL blockLabelVerCenter;

#pragma mark- debug
- (void)printView:(UIView*)view level:(NSInteger)level;

#pragma mark- aux methods
/**
 *  (public) get owner tableview
 */
- (UITableView*)getParentTableView;

/**
 *  (public) 辅助计算文字尺寸
 */
- (CGSize)auxSizeWithText:(NSString*)text font:(UIFont*)font maxsize:(CGSize)maxsize;

/**
 *  (public) 辅助着色
 */
+ (NSMutableAttributedString*)genAndColorAttributedText:(NSString*)titleString
                                                  value:(NSString*)valueString
                                             titleColor:(UIColor*)titleColor
                                             valueColor:(UIColor*)valueColor;

- (NSMutableAttributedString*)genAndColorAttributedText:(NSString*)titleString
                                                  value:(NSString*)valueString
                                             titleColor:(UIColor*)titleColor
                                             valueColor:(UIColor*)valueColor;

@end
