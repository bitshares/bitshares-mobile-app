//
//  UITableViewBase.h
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import <UIKit/UIKit.h>

@interface UITableViewBase : UITableView

@property (nonatomic, assign) BOOL hideAllLines;

/**
 *  (public) 在CELL的附加View上关联输入框。（自动适配输入框宽度）
 */
- (void)attachTextfieldToCell:(UITableViewCell*)cell tf:(UITextField*)tf;

@end
