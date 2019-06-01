//
//  VCBase.h
//  oplayer
//
//  Created by SYALON on 13-12-2.
//
//

#import <UIKit/UIKit.h>
#import "WsPromise.h"
#import "Extension.h"
#import "ThemeManager.h"
#import "NativeAppDelegate.h"
#import "MyNavigationController.h"
#import "UIAlertViewManager.h"
#import "MyPopviewManager.h"
#import "TempManager.h"
#import "SettingManager.h"

#import "MyTextField.h"

#import "VCCommonLogic.h"

#import "ViewBlockButton.h"
#import "ViewBlockLabel.h"
#import "UITableViewBase.h"
#import "UITableViewCellBase.h"

#import "NSObject+Reflection.h"
#import "UIImage+Template.h"

#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

#import "IntervalManager.h"
#import "ChainObjectManager.h"
#import "WalletManager.h"
#import "BitsharesClientManager.h"
#import "GrapheneConnectionManager.h"

#import "SCLAlertView.h"
#import "OrgUtils.h"
#import <Flurry/Flurry.h>

#import "LangManager.h"

@interface VCBase : UIViewController<UITextFieldDelegate,UITableViewDelegate>
{
    NSMutableDictionary* _e;
    NSInteger _notify_unique_id;
    NSInteger _model_tag_id;
}

@property (nonatomic, retain) NSMutableDictionary* e;
@property (nonatomic, assign) NSInteger notify_unique_id;
@property (nonatomic, assign) NSInteger model_tag_id;

#pragma mark- heights
- (CGFloat)heightForStatusBar;
- (CGFloat)heightForNavigationBar;
- (CGFloat)heightForTabBar;
- (CGFloat)heightForStatusAndNaviBar;
- (CGFloat)heightForkSearchBar;
- (CGFloat)heightForToolBar;
- (CGFloat)heightForBottomSafeArea;
- (BOOL)isIphoneX;

#pragma mark- bitshares api wapper
- (WsPromise*)bapi_db_exec:(NSString*)api_name params:(NSArray*)args;
//- (WsPromise*)bapi_db_get_full_accounts:(NSString*)name_or_id;
- (WsPromise*)get_full_account_data_and_asset_hash:(NSString*)account_name_or_id;

#pragma mark- some kinds of rect...

- (CGRect)rectWithoutNaviAndTab;
- (CGRect)rectWithoutNaviAndTool;
- (CGRect)rectWithoutTabbar;
- (CGRect)rectWithoutNaviAndPageBar;
- (CGRect)rectWithoutNavi;

- (void)showBlockViewWithTitle:(NSString*)pTitle subTitle:(NSString*)pSubTitle;
- (void)showBlockViewWithTitle:(NSString*)pTitle;
- (void)hideBlockView;

- (MyNavigationController*)myNavigationController;

//  创建色块按钮，默认是 next 类型的主按钮。
- (ViewBlockLabel*)createCellLableButton:(NSString*)text;
- (ViewBlockLabel*)createCellLableButtonCore:(NSString*)text isnextbutton:(BOOL)isnextbutton;
- (void)refreshCellLabelColor:(ViewBlockLabel*)label;
- (void)addLabelButtonToCell:(ViewBlockLabel*)label cell:(UITableViewCell*)cell leftEdge:(CGFloat)leftEdge;
- (void)updateCellLabelButtonText:(ViewBlockLabel*)label text:(NSString*)text;

- (UIButton*)createCellButton:(NSString*)text action:(SEL)action;
- (void)addCellButtonToCell:(UIButton*)btn cell:(UITableViewCell*)cell;
- (void)refreshCellButtonColor:(UIButton*)btn;
- (void)addCellButtonToCellAsChild:(UIButton*)btn cell:(UITableViewCell*)cell changeColor:(BOOL)changeColor;
- (void)addCellButtonToView:(UIButton*)btn view:(UIView*)view;

#pragma mark- for textfield
- (MyTextField*)createTfWithRect:(CGRect)rect keyboard:(UIKeyboardType)kbt placeholder:(NSString*)placeholder;
- (MyTextField*)createTfWithRect:(CGRect)rect
                        keyboard:(UIKeyboardType)kbt
                     placeholder:(NSString *)placeholder
                          action:(SEL)action
                             tag:(NSInteger)tag;
- (CGRect)makeTextFieldRectFull;
- (CGRect)makeTextFieldRect;
- (CGRect)makeTextFieldShortRect;
- (CGRect)makeTextFieldTipRect;

- (UITableViewCellBase*)getOrCreateTableViewCellBase:(UITableView*)tableView style:(UITableViewCellStyle)style reuseIdentifier:(NSString*)identify;

- (void)showRightImageButton:(NSString*)imageName action:(SEL)action color:(UIColor*)tintColor;
- (void)showLeftImageButton:(NSString*)imageName action:(SEL)action color:(UIColor*)tintColor;
- (void)showRightButton:(NSString*)title action:(SEL)action;
- (void)showLeftButton:(NSString*)title action:(SEL)action;

- (BOOL)isStringEmpty:(NSString*)str;

/**
 *  辅助 - 创建上下垂直居中的空数据 Label。
 */
- (UILabel*)genCenterEmptyLabel:(CGRect)rect txt:(NSString*)txt;

- (void)showModelViewController:(VCBase*)vc tag:(NSInteger)tagid;
- (void)onModelViewControllerClosed:(NSDictionary*)args tag:(NSInteger)tag;
- (void)closeModelViewController:(NSDictionary*)args;
- (void)closeOrPopViewController;

#pragma mark- fo wallet new...
/**
 *  (public)权限不足时，询问用户是否发起提案交易。
 */
- (void)askForCreateProposal:(EBitsharesOperations)opcode
       using_owner_authority:(BOOL)using_owner_authority
    invoke_proposal_callback:(BOOL)invoke_proposal_callback
                      opdata:(id)opdata
                   opaccount:(id)opaccount
                        body:(void (^)(BOOL isProposal, NSDictionary* proposal_create_args))body
            success_callback:(void (^)())success_callback;
/**
 *  (public) 确保交易权限。足够-发起普通交易，不足-提醒用户发起提案交易。
 */
- (void)GuardProposalOrNormalTransaction:(EBitsharesOperations)opcode
                   using_owner_authority:(BOOL)using_owner_authority
                invoke_proposal_callback:(BOOL)invoke_proposal_callback
                                  opdata:(id)opdata
                               opaccount:(id)opaccount
                                    body:(void (^)(BOOL isProposal, NSDictionary* proposal_create_args))body;
/**
 *  确保钱包已经解锁、检测是否包含资金私钥权限。
 */
- (void)GuardWalletUnlocked:(BOOL)checkActivePermission body:(void (^)(BOOL unlocked))body;
/**
 *  确保钱包已经解锁（并且钱包存在）
 */
- (void)GuardWalletUnlocked:(void (^)(BOOL unlocked))body;
/**
 *  确保钱包已经存在
 */
- (void)GuardWalletExist:(void (^)())body;
/**
 *  延迟调用，tableview的cell中执行很多页面跳转行为有延迟，需要ui主线程处理。比如：presentViewController 延迟很大。
 */
- (void)delay:(void (^)())body;

/**
 *  (public) refresh back text when SWITCH LANGUAGE
 */
- (void)refreshBackButtonText;

- (void)pushViewController:(UIViewController*)vc vctitle:(NSString*)vctitle backtitle:(NSString*)backtitle;
- (void)clearPushViewController:(UIViewController*)vc vctitle:(NSString*)vctitle backtitle:(NSString*)backtitle;

#pragma mark- debug
- (void)printView:(UIView*)view level:(NSInteger)level;

#pragma mark- switch theme
- (void)switchTheme;

#pragma mark- switch language
- (void)switchLanguage;


#pragma mark- override in subclass
- (void)reloadTableView:(UITableView*)tableView;

@end
