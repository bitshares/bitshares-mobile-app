//
//  ViewTextFieldAmountCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//  转账/提币/销毁/清算等数量输入框，末尾带【全部】快捷按钮。
//  TODO:7.0 后期考虑用 ViewAdvTextFieldCell 界面代替。

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@class ViewTextFieldAmountCell;
@protocol ViewTextFieldAmountCellDelegate <UITextFieldDelegate>

- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onAmountChanged:(NSDecimalNumber*)newValue;
- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onTailerClicked:(UIButton*)sender;

@end

@interface ViewTextFieldAmountCell : UITableViewCellBase<UITextFieldDelegate>

- (id)initWithTitle:(NSString*)title placeholder:(NSString*)placeholder tailer:(NSString*)tailer;

- (void)endInput;
- (NSString*)getInputTextValue;
- (void)setInputTextValue:(NSString*)newValue;
- (void)clearInputTextValue;
- (void)drawUI_newTailer:(NSString*)text;
- (void)drawUI_titleValue:(NSString*)text color:(UIColor*)color;

@property (nonatomic, assign) id<ViewTextFieldAmountCellDelegate> delegate;

@end
