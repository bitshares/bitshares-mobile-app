//
//  ViewAdvTextFieldCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//  UITableView中的常见输入控件封装类。包括 标题/输入框/格式提示框等信息。

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "ViewFormatConditons.h"

//@class ViewAdvTextFieldCell;
//@protocol ViewAdvTextFieldCellDelegate <UITextFieldDelegate>
//
//- (void)textFieldAmount:(ViewAdvTextFieldCell*)sheet onAmountChanged:(NSDecimalNumber*)newValue;
//- (void)textFieldAmount:(ViewAdvTextFieldCell*)sheet onTailerClicked:(UIButton*)sender;
//
//@end

@class MyTextField;
@interface ViewAdvTextFieldCell : UITableViewCellBase<UITextFieldDelegate>

- (id)initWithTitle:(NSString*)title placeholder:(NSString*)placeholder;
- (id)initWithTitle:(NSString*)title placeholder:(NSString*)placeholder decimalPrecision:(NSInteger)decimalPrecision;

- (void)endInput;

/*
 *  (public) 在输入框尾部生成帮助资产名称视图。
 */
- (void)genTailerAssetName:(NSString*)asset_name;
/*
 *  (public) 在输入框尾部生成资产名称和各种按钮集合的视图。
 */
- (void)genTailerAssetNameAndButtons:(NSString*)asset_name button_names:(NSArray*)button_names target:(id)target action:(SEL)action;

/*
 *  (public) 生成帮助问号的 tailerView。
 */
- (void)genHelpTailerView:(id)target action:(SEL)action tag:(NSInteger)tag;

/*
 *  (public) 在 titleValue 后面生成帮助按钮。
 */
- (void)genHelpButton:(id)target action:(SEL)action tag:(NSInteger)tag;

/*
 *  (public) 生成条件视图。
 */
- (void)genFormatConditonsView:(void (^)(ViewFormatConditons* formatConditonsView))config_body;

/*
 *  (public) 辅助 - 快速生成【钱包密码】格式的条件视图。
 */
- (void)auxFastConditionsViewForWalletPassword;

/*
 *  (public) 辅助 - 快速生成【账号模式的账号密码】格式的条件视图。
 */
- (void)auxFastConditionsViewForAccountPassword;

/*
 *  (public) 辅助 - 快速生成【账号名】格式的条件视图。
 */
- (void)auxFastConditionsViewForAccountNameFormat;

//- (NSString*)getInputTextValue;
//- (void)setInputTextValue:(NSString*)newValue;
//- (void)clearInputTextValue;
//- (void)drawUI_newTailer:(NSString*)text;
//- (void)drawUI_titleValue:(NSString*)text color:(UIColor*)color;

//@property (nonatomic, assign) id<ViewAdvTextFieldCellDelegate> delegate;

@property (nonatomic, strong) UILabel* labelTitle;
@property (nonatomic, strong) UILabel* labelValue;
@property (nonatomic, strong) UIButton* helpButton;
@property (nonatomic, strong) MyTextField* mainTextfield;
@property (nonatomic, strong) ViewFormatConditons* formatConditonsView;

@property (nonatomic, assign, readonly) BOOL isAllConditionsMatched;
@property (nonatomic, assign) CGFloat cellHeight;

@end
