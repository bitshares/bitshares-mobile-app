//
//  VCBase.m
//  oplayer
//
//  Created by SYALON on 13-12-2.
//
//

#import "VCBase.h"
#import "BitsharesClientManager.h"
#import "WalletManager.h"
#import "VCProposalConfirm.h"
#import "VCImportAccount.h"
#import "MBProgressHUDSingleton.h"
#import "NativeAppDelegate.h"
#import "MyNavigationController.h"
#import "OrgUtils.h"
#import "UIDevice+Helper.h"

#import "Crashlytics/Crashlytics.h"

static NSInteger __s_notify_unique_id = 0;  //  REMAKR：计数器（所有模态vc显示次数，每显示1次加。）

static NSInteger gen_notify_unique_id()
{
    NSInteger v = ++__s_notify_unique_id;
    //  重置ID号
    if (__s_notify_unique_id >= 0xfffffff){
        __s_notify_unique_id = 0;
    }
    return v;
}

@interface VCBase ()
{
}

@end

@implementation VCBase

@synthesize e = _e;
@synthesize notify_unique_id = _notify_unique_id;
@synthesize model_tag_id = _model_tag_id;

#pragma mark- heights
/**
 *  状态栏高度   TODO:状态栏高度当有热点连接or语音通话时会发生改变。
 */
- (CGFloat)heightForStatusBar
{
    return [UIApplication sharedApplication].statusBarFrame.size.height;
}
/**
 *  导航栏高度
 */
- (CGFloat)heightForNavigationBar
{
    return 44.0f;
}
/**
 *  Tab栏高度
 */
- (CGFloat)heightForTabBar
{
    return 49;
}
/**
 *  状态栏＋导航栏一起的高度
 */
- (CGFloat)heightForStatusAndNaviBar
{
    return [self heightForStatusBar] + [self heightForNavigationBar];
}
/**
 *  搜索栏高度
 */
- (CGFloat)heightForkSearchBar
{
    return 44.0f;
}
/**
 *  工具栏高度
 */
- (CGFloat)heightForToolBar
{
    return 46.0f;
}
/**
 *  底部安全区域高度（仅iphonex存在）
 */
- (CGFloat)heightForBottomSafeArea
{
    return [self isIphoneX] ? 34 : 0;
}
/**
 *  是否是 iphonex 判断
 */
- (BOOL)isIphoneX
{
    return [[UIScreen mainScreen] bounds].size.height == 812.0f;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _e = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSString *className = [NSString stringWithUTF8String:object_getClassName(self)];
    CLS_LOG(@"viewDidLoad: %@", className);
    //  [统计]
    [OrgUtils logEvents:@"viewDidLoad" params:@{@"view":className}];
    
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    self.edgesForExtendedLayout = UIRectEdgeNone;
}

- (void)viewDidDisappear:(BOOL)animated
{
    CLS_LOG(@"viewDidDisappear: %@", [NSString stringWithUTF8String:object_getClassName(self)]);
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc
{
    self.e = nil;
    
//    //  清除所有 tableView 的所有代理 执行到这里很多对象都释放了 crash
//    for (UITableView* tableView in [self getIvarList:[UITableView class]]) {
//        tableView.delegate = nil;
//    }
}

#pragma mark- bitshares api wapper

- (WsPromise*)bapi_db_exec:(NSString*)api_name params:(NSArray*)args
{
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    return [api exec:api_name params:args];
}

/**
 *  获取用户的 full_account_data 数据，并且获取余额里所有 asset 的资产详细信息。
 */
- (WsPromise*)get_full_account_data_and_asset_hash:(NSString*)account_name_or_id
{
    return [[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_name_or_id] then:(^id(id full_account_data) {
        id asset_type_list = [[full_account_data objectForKey:@"balances"] ruby_map:(^id(id src) {
            return [src objectForKey:@"asset_type"];
        })];
        return [[[ChainObjectManager sharedChainObjectManager] queryAllAssetsInfo:asset_type_list] then:(^id(id asset_hash) {
            //  (void)asset_hash 省略，缓存到 ChainObjectManager 即可。
            return full_account_data;
        })];
    })];
}

#pragma mark- some kinds of rect...

- (CGRect)rectWithoutNaviAndTab
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    return CGRectMake(0, 0, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - [self heightForTabBar] - [self heightForBottomSafeArea]);
}

- (CGRect)rectWithoutNaviAndTool
{
    //  TODO:fowallet heightForBottomSafeArea??
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    return CGRectMake(0, 0, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - [self heightForToolBar]);
}

- (CGRect)rectWithoutTabbar
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    return CGRectMake(0, 0, screenRect.size.width, screenRect.size.height - [self heightForTabBar] - [self heightForBottomSafeArea]);
}

- (CGRect)rectWithoutNaviAndPageBar
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    //  TODO:fowallet 32这个宽度
    return CGRectMake(0, 0, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - 32 - [self heightForBottomSafeArea]);
}

- (CGRect)rectWithoutNavi
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    return CGRectMake(0, 0, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - [self heightForBottomSafeArea]);
}

#pragma mark- cell label button

- (ViewBlockLabel*)createCellLableButton:(NSString*)text
{
    return [self createCellLableButtonCore:text isnextbutton:YES];
}

- (ViewBlockLabel*)createCellLableButtonCore:(NSString*)text isnextbutton:(BOOL)isnextbutton
{
    ViewBlockLabel* label = [[ViewBlockLabel alloc] initWithFrame:CGRectZero];
    
    label.bIsNextButton = isnextbutton;
    
    UIColor* textColor = isnextbutton ? [ThemeManager sharedThemeManager].mainButtonTextColor : [ThemeManager sharedThemeManager].blockButtonTextColor;
    UIColor* backColor = isnextbutton ? [ThemeManager sharedThemeManager].mainButtonBackColor : [ThemeManager sharedThemeManager].blockButtonBackColor;
    
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = textColor;
    label.font = [UIFont systemFontOfSize:17];
    label.text = text;
    
    label.layer.borderWidth = 1;
    label.layer.borderColor = backColor.CGColor;
    //  REMARK：去除登录等按钮等弧度
    label.layer.cornerRadius = 0.0f;
//    label.layer.cornerRadius = 3.0f;
    label.layer.masksToBounds = YES;
    
    label.layer.backgroundColor = backColor.CGColor;
    
    return label;
}

- (void)refreshCellLabelColor:(ViewBlockLabel*)label
{
    BOOL isnextbutton = label.bIsNextButton;
    
    UIColor* textColor = isnextbutton ? [ThemeManager sharedThemeManager].mainButtonTextColor : [ThemeManager sharedThemeManager].blockButtonTextColor;
    UIColor* backColor = isnextbutton ? [ThemeManager sharedThemeManager].mainButtonBackColor : [ThemeManager sharedThemeManager].blockButtonBackColor;
    
    label.textColor = textColor;
    label.layer.borderColor = backColor.CGColor;
    label.layer.backgroundColor = backColor.CGColor;
}

- (void)addLabelButtonToCell:(ViewBlockLabel*)label cell:(UITableViewCell*)cell leftEdge:(CGFloat)leftEdge
{
    if (label.superview)
    {
        [label removeFromSuperview];
    }
    
    CGSize limitSize = CGSizeMake(self.view.bounds.size.width, cell.bounds.size.height);

    CGFloat w = self.view.bounds.size.width - leftEdge * 2;
    CGFloat h = 38; //  REMARK：主要按钮高度
    
    label.frame = CGRectMake((limitSize.width - w) / 2.0f, (limitSize.height - h) / 2.0f, w, h);
    cell.accessibilityTraits = UIAccessibilityTraitButton;

    [cell.contentView addSubview:label];
}

- (void)updateCellLabelButtonText:(ViewBlockLabel*)label text:(NSString*)text
{
    //  尚未添加到cell中不更新
    if (!label.superview){
        return;
    }
    
    UITableViewCell* cell = (UITableViewCell*)label.superview;
    
    label.text = text;
    
    CGSize limitSize = CGSizeMake(self.view.bounds.size.width, cell.bounds.size.height);
    
    CGSize textSize = [label.text sizeWithFont:label.font constrainedToSize:limitSize];
    
    CGFloat w = textSize.width + 8;
    CGFloat h = textSize.height + 10;
    
    label.frame = CGRectMake((limitSize.width - w) / 2.0f, (limitSize.height - h) / 2.0f, w, h);
}

- (UIButton*)createCellButton:(NSString*)text action:(SEL)action
{
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:text forState:UIControlStateNormal];
    [btn setTitleColor:[ThemeManager sharedThemeManager].frameButtonTextColor forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [ThemeManager sharedThemeManager].frameButtonBorderColor.CGColor;
    btn.layer.cornerRadius = 3.0f;
    btn.layer.masksToBounds = YES;
    
    return btn;
}

- (void)refreshCellButtonColor:(UIButton*)btn
{
    [btn setTitleColor:[ThemeManager sharedThemeManager].frameButtonTextColor forState:UIControlStateNormal];
    btn.layer.borderColor = [ThemeManager sharedThemeManager].frameButtonBorderColor.CGColor;
}

- (void)addCellButtonToCell:(UIButton*)btn cell:(UITableViewCell*)cell
{
    [self setButtonBorder:btn cell:cell changeColor:YES];
    cell.accessoryView = btn;
}

- (void)addCellButtonToCellAsChild:(UIButton*)btn cell:(UITableViewCell*)cell changeColor:(BOOL)changeColor
{
    [self setButtonBorder:btn cell:cell changeColor:changeColor];
    [cell.contentView addSubview:btn];
}

- (void)addCellButtonToView:(UIButton*)btn view:(UIView*)view
{
    [self setButtonBorder:btn cell:view changeColor:YES];
    [view addSubview:btn];
}

#pragma mark- private
- (void)setButtonBorder:(UIButton*)btn cell:(UIView*)cell changeColor:(BOOL)changeColor
{
    CGSize limitSize = CGSizeMake(self.view.bounds.size.width, cell.bounds.size.height);
    
    CGSize textSize = [btn.titleLabel.text sizeWithFont:btn.titleLabel.font constrainedToSize:limitSize];
    
    CGFloat w = textSize.width + 8;
    CGFloat h = textSize.height + 10;
    
    btn.frame = CGRectMake((limitSize.width - w) / 2.0f, (limitSize.height - h) / 2.0f, w, h);
    btn.layer.borderWidth = 1;
    if (changeColor){
        btn.layer.borderColor = [ThemeManager sharedThemeManager].frameButtonBorderColor.CGColor;
    }
    btn.layer.cornerRadius = 3.0f;
    btn.layer.masksToBounds = YES;
}

/**
 *  (public) refresh back text when SWITCH LANGUAGE
 */
- (void)refreshBackButtonText
{
    UIBarButtonItem* barButtonItem = [[UIBarButtonItem alloc] initWithTitle:kVcDefaultBackTitleName
                                                                      style:UIBarButtonItemStyleDone
                                                                     target:nil
                                                                     action:nil];
    self.navigationItem.backBarButtonItem = barButtonItem;
}

/**
 *  导航到下一级、便捷方式。
 */
- (void)pushViewController:(UIViewController*)vc vctitle:(NSString*)vctitle backtitle:(NSString*)backtitle
{
    if (backtitle){
        UIBarButtonItem* barButtonItem = [[UIBarButtonItem alloc] initWithTitle:backtitle style:UIBarButtonItemStyleDone target:nil action:nil];
        self.navigationItem.backBarButtonItem = barButtonItem;
    }
    if (vctitle){
        vc.title = vctitle;
    }
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

/**
 *  push 导航，并在 push 结束后清理导航堆栈，保留首页和自身页面。
 */
- (void)clearPushViewController:(UIViewController*)vc vctitle:(NSString*)vctitle backtitle:(NSString*)backtitle
{
    [TempManager sharedTempManager].clearNavbarStackOnVcPushCompleted = vc;
    [self pushViewController:vc vctitle:vctitle backtitle:backtitle];
}

- (void)viewDidAppear:(BOOL)animated
{
    CLS_LOG(@"viewDidAppear: %@", [NSString stringWithUTF8String:object_getClassName(self)]);
    [super viewDidAppear:animated];
    //  REMARK: 在push完毕后清除堆栈
    id pushClearVc = [TempManager sharedTempManager].clearNavbarStackOnVcPushCompleted;
    if (pushClearVc && pushClearVc == self)
    {
        [TempManager sharedTempManager].clearNavbarStackOnVcPushCompleted = nil;
        UIViewController* root = [self.navigationController.viewControllers firstObject];
        if (root != self){
            self.navigationController.viewControllers = [NSArray arrayWithObjects:root, self, nil];
        }else{
            self.navigationController.viewControllers = [NSArray arrayWithObjects:root, nil];
        }
    }
}

#pragma mark- ui textfield
- (MyTextField*)createTfWithRect:(CGRect)rect keyboard:(UIKeyboardType)kbt placeholder:(NSString*)placeholder
{
    MyTextField* tf = [[MyTextField alloc] initWithFrame:rect];
    
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    tf.keyboardType = kbt;
    tf.returnKeyType = UIReturnKeyNext;
    tf.delegate = self;
    tf.placeholder = placeholder;
    tf.borderStyle = UITextBorderStyleNone;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.tintColor = [ThemeManager sharedThemeManager].tintColor;
    
    return tf;
}

- (MyTextField*)createTfWithRect:(CGRect)rect
                        keyboard:(UIKeyboardType)kbt
                     placeholder:(NSString *)placeholder
                          action:(SEL)action
                             tag:(NSInteger)tag
{
    MyTextField* tf = [self createTfWithRect:rect keyboard:kbt placeholder:placeholder];
    
    //  右边帮助按钮
    UIButton* btnTips = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];
    [btnTips setBackgroundImage:btn_image forState:UIControlStateNormal];
    btnTips.userInteractionEnabled = YES;
    [btnTips addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    btnTips.frame = CGRectMake(0, 0, btn_image.size.width, btn_image.size.height);
    btnTips.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
    btnTips.tag = tag;
    
    //  设置 rightView
    tf.rightView = btnTips;
    tf.rightViewMode = UITextFieldViewModeAlways;
    
    return tf;
}

/**
 *  计算textfield的矩形尺寸（尽量匹配UITableViewCell宽度，不显示左边字符串。
 */
- (CGRect)makeTextFieldRectFull
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    //  REMARK：32是16的两倍，16是textLabel左边距离。貌似ipad不对？
    return CGRectMake(0, 0, screenRect.size.width - 32, 31);
}

/**
 *  计算textfield的矩形尺寸
 */
- (CGRect)makeTextFieldRect
{
    //  CGRect rect = [UIDevice isRunningOniPad] ? CGRectMake(0, 0, 768-205, 31) : CGRectMake(0, 0, 215, 31);
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    //  REMARK：原来ipad和ios的宽度都70%左右。为了适配6plus等高分辨率模式，采用百分比。
    return CGRectMake(0, 0, screenRect.size.width * kAppTextFieldWidthFactor, 31);
}

/**
 *  计算textfield的短模式的矩形尺寸（类似密码框后面带了个找回密码按钮）
 */
- (CGRect)makeTextFieldShortRect
{
    //  REMARK：参考 makeTextFieldRect
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    return CGRectMake(0, 0, screenRect.size.width * kAppTextFieldWidthFactor - 96, 31);
}

/**
 *  计算textfield的短模式的矩形尺寸（后面带了个tips按钮）
 */
- (CGRect)makeTextFieldTipRect
{
    //  REMARK：参考 makeTextFieldRect
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    return CGRectMake(0, 0, screenRect.size.width * kAppTextFieldWidthFactor - 48, 31);
}

#pragma mark- ui tableview
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (tableView.style == UITableViewStylePlain){
        return 0.01;
    }else{
        if (section == 0)
            return 15;
        else
            return 0.01;
    }
}

- (UITableViewCellBase*)getOrCreateTableViewCellBase:(UITableView*)tableView style:(UITableViewCellStyle)style reuseIdentifier:(NSString*)identify
{
    UITableViewCellBase* cell = (UITableViewCellBase *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[UITableViewCellBase alloc] initWithStyle:style reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    else
    {
        NSLog(@"reuse: %@", identify);
    }
    return cell;
}

#pragma mark- navigation button

- (void)showRightImageButton:(NSString*)imageName action:(SEL)action color:(UIColor*)tintColor
{
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* image = [UIImage templateImageNamed:imageName];
    [btn setBackgroundImage:image forState:UIControlStateNormal];
    btn.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    if (tintColor){
        btn.tintColor = tintColor;
    }
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:btn];
}

- (void)showLeftImageButton:(NSString*)imageName action:(SEL)action color:(UIColor*)tintColor
{
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* image = [UIImage templateImageNamed:imageName];
    [btn setBackgroundImage:image forState:UIControlStateNormal];
    btn.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    if (tintColor){
        btn.tintColor = tintColor;
    }
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:btn];
}

- (void)showRightButton:(NSString*)title action:(SEL)action
{
    UIBarButtonItem* btn = [[UIBarButtonItem alloc] initWithTitle:title
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:action];
    self.navigationItem.rightBarButtonItem = btn;
}

- (void)showLeftButton:(NSString*)title action:(SEL)action
{
    UIBarButtonItem* btn = [[UIBarButtonItem alloc] initWithTitle:title
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:action];
    self.navigationItem.leftBarButtonItem = btn;
}

#pragma mark- block view

- (void)showBlockViewWithTitle:(NSString*)pTitle subTitle:(NSString*)pSubTitle
{
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing])
    {
        [[MBProgressHUDSingleton sharedMBProgressHUDSingleton] updateTitle:pTitle subTitle:pSubTitle];
        return;
    }
    [self.myNavigationController tempDisableDragBack];
    //  如果在pop出来的vc里显示界面则可能没有tabbar
    UIView* view = nil;
    if (self.tabBarController && self.tabBarController.view){
        view = self.tabBarController.view;
    }else{
        view = self.navigationController.view;
    }
    [[MBProgressHUDSingleton sharedMBProgressHUDSingleton] showWithTitle:pTitle subTitle:pSubTitle andView:view];
}

- (void)showBlockViewWithTitle:(NSString*)pTitle
{
    [self showBlockViewWithTitle:pTitle subTitle:nil];
}

- (void)hideBlockView
{
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing])
    {
        [self.myNavigationController tempEnableDragBack];
        [[MBProgressHUDSingleton sharedMBProgressHUDSingleton] hide];
    }
}

- (MyNavigationController*)myNavigationController
{
    return (MyNavigationController*)self.navigationController;
}

#pragma mark- utils

- (BOOL)isStringEmpty:(id)str
{
    if (!str){
        return YES;
    }
    if ([str isKindOfClass:[NSString class]]){
        if ([str isEqualToString:@""]){
            return YES;
        }
    }
    return NO;
}

/**
 *  辅助 - 创建上下垂直居中的空数据 Label。
 */
- (UILabel*)genCenterEmptyLabel:(CGRect)rect txt:(NSString*)txt
{
    assert(txt);
    UILabel* lbEmpty = [[UILabel alloc] initWithFrame:rect];
    lbEmpty.lineBreakMode = NSLineBreakByWordWrapping;
    lbEmpty.numberOfLines = 1;
    lbEmpty.contentMode = UIViewContentModeCenter;
    lbEmpty.backgroundColor = [UIColor clearColor];
    lbEmpty.textColor = [ThemeManager sharedThemeManager].textColorMain;
    lbEmpty.textAlignment = NSTextAlignmentCenter;
    lbEmpty.font = [UIFont boldSystemFontOfSize:13];
    lbEmpty.text = txt;
    lbEmpty.hidden = YES;
    return lbEmpty;
}

#pragma mark- show model view controller
- (void)showModelViewController:(VCBase*)vc tag:(NSInteger)tagid
{
    vc.model_tag_id = tagid;
    [self presentViewController:[[NativeAppDelegate sharedAppDelegate] newNavigationController:vc] animated:YES completion:^
    {
        vc.notify_unique_id = gen_notify_unique_id();
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onNoticeOnModelViewControllerClosed:)
                                                     name:[NSString stringWithFormat:@"%@_%@", kNoticeOnModelViewControllerClosed, @(vc.notify_unique_id)]
                                                   object:nil];
    }];
}

//  private
- (void)onNoticeOnModelViewControllerClosed:(NSNotification *)notification
{
    NSDictionary* notify = [notification userInfo];
    NSString* kNotifyName = [notify objectForKey:@"kNotifyName"];
    NSInteger kTag = [[notify objectForKey:@"kTag"] integerValue];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotifyName object:nil];
    [self onModelViewControllerClosed:[notify objectForKey:@"kArgs"] tag:kTag];
}

- (void)onModelViewControllerClosed:(NSDictionary*)args tag:(NSInteger)tag
{
    //  子类中处理
}

- (void)closeModelViewController:(NSDictionary*)args
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^
    {
        NSString* kNotifyName = [NSString stringWithFormat:@"%@_%@", kNoticeOnModelViewControllerClosed, @(self.notify_unique_id)];
        NSDictionary* userInfo;
        if (args){
            userInfo = [NSDictionary dictionaryWithObjectsAndKeys:args, @"kArgs", kNotifyName, @"kNotifyName", @(self.model_tag_id), @"kTag", nil];
        }else{
            userInfo = [NSDictionary dictionaryWithObjectsAndKeys:kNotifyName, @"kNotifyName", @(self.model_tag_id), @"kTag", nil];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotifyName object:nil userInfo:userInfo];
    }];
}

/**
 *  关闭present模式显示的vc或者push显示的vc。
 */
- (void)closeOrPopViewController
{
    //  REMARK：self.presentingViewController 这个vc用present显示出了了 self 这个vc，说明 self 是present模式显示的。则关闭模态vc。
    if (self.presentingViewController){
        [self closeModelViewController:nil];
    }else{
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark- guard

/**
 *  (private) 创建提案请求
 */
- (void)onExecuteCreateProposalCore:(EBitsharesOperations)opcode
                             opdata:(id)opdata
                          opaccount:(id)opaccount
               proposal_create_args:(id)proposal_create_args
                   success_callback:(void (^)())success_callback
{
    assert(opdata);
    assert(proposal_create_args);
    id fee_paying_account = [proposal_create_args objectForKey:@"kFeePayingAccount"];
    assert(fee_paying_account);
    NSString* fee_paying_account_id = [fee_paying_account objectForKey:@"id"];
    assert(fee_paying_account_id);
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[BitsharesClientManager sharedBitsharesClientManager] proposalCreate:opcode
                                                                     opdata:opdata
                                                                  opaccount:opaccount
                                                       proposal_create_args:proposal_create_args] then:(^id(id data)
    {
        [self hideBlockView];
        //  成功回调
        if (success_callback){
            success_callback();
        }else{
            [OrgUtils makeToast:NSLocalizedString(@"kProposalSubmitTipTxOK", @"创建提案成功。")];
        }
        //  [统计]
        [OrgUtils logEvents:@"txProposalCreateOK" params:@{@"opcode":@(opcode), @"account":fee_paying_account_id}];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        //  [统计]
        [OrgUtils logEvents:@"txProposalCreateFailed" params:@{@"opcode":@(opcode), @"account":fee_paying_account_id}];
        return nil;
    })];
}

/**
 *  (public)权限不足时，询问用户是否发起提案交易。
 */
- (void)askForCreateProposal:(EBitsharesOperations)opcode
       using_owner_authority:(BOOL)using_owner_authority
    invoke_proposal_callback:(BOOL)invoke_proposal_callback
                      opdata:(id)opdata
                   opaccount:(id)opaccount
                        body:(void (^)(BOOL isProposal, NSDictionary* proposal_create_args))body
            success_callback:(void (^)())success_callback
{
    id account_name = [opaccount objectForKey:@"name"];
    assert(account_name);
    NSString* message;
    if (using_owner_authority){
        message = [NSString stringWithFormat:NSLocalizedString(@"kProposalTipsAskMissingOwner", @"您没有账号 %@ 的账号权限，是否发起提案交易？"), account_name];
    }else{
        message = [NSString stringWithFormat:NSLocalizedString(@"kProposalTipsAskMissingActive", @"您没有账号 %@ 的资金权限，是否发起提案交易？"), account_name];
    }
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:message
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
         if (buttonIndex == 1)
         {
             // 转到提案确认界面
             VCProposalConfirm* vc = [[VCProposalConfirm alloc] initWithOpcode:opcode
                                                                        opdata:opdata
                                                                     opaccount:opaccount
                                                                      callback:^(BOOL isOk, NSDictionary* proposal_create_args)
                                      {
                                          if (isOk){
                                              if (invoke_proposal_callback){
                                                  assert(body);
                                                  body(YES, proposal_create_args);
                                              }else{
                                                  [self onExecuteCreateProposalCore:opcode
                                                                             opdata:opdata
                                                                          opaccount:opaccount
                                                               proposal_create_args:proposal_create_args
                                                                   success_callback:success_callback];
                                              }
                                          }else{
                                              NSLog(@"cancel create proposal...");
                                          }
                                      }];
             vc.title = NSLocalizedString(@"kVcTitleCreateProposal", @"请确认提案");
             vc.hidesBottomBarWhenPushed = YES;
             [self showModelViewController:vc tag:0];
         }
     }];
}

/**
 *  (public) 确保交易权限。足够-发起普通交易，不足-提醒用户发起提案交易。
 *  using_owner_authority - 是否使用owner授权，否则验证active权限。
 */
- (void)GuardProposalOrNormalTransaction:(EBitsharesOperations)opcode
                   using_owner_authority:(BOOL)using_owner_authority
                invoke_proposal_callback:(BOOL)invoke_proposal_callback
                                  opdata:(id)opdata
                               opaccount:(id)opaccount
                                    body:(void (^)(BOOL isProposal, NSDictionary* proposal_create_args))body
{
    assert(opdata);
    assert(opaccount);
    
    NSDictionary* permission_json = using_owner_authority ? [opaccount objectForKey:@"owner"] : [opaccount objectForKey:@"active"];
    assert(permission_json);
    if ([[WalletManager sharedWalletManager] canAuthorizeThePermission:permission_json]){
        //  权限足够
        body(NO, nil);
    }else{
        //  没权限，询问用户是否发起提案。
        [self askForCreateProposal:opcode
             using_owner_authority:using_owner_authority
          invoke_proposal_callback:invoke_proposal_callback
                            opdata:opdata
                         opaccount:opaccount
                              body:body
                  success_callback:nil];
    }
}

/**
 *  确保钱包已经解锁、检测是否包含资金私钥权限。
 */
- (void)GuardWalletUnlocked:(BOOL)checkActivePermission body:(void (^)(BOOL unlocked))body
{
    [self GuardWalletExist:^{
        if ([[WalletManager sharedWalletManager] isLocked]){
            id title = kwmPasswordOnlyMode == [[WalletManager sharedWalletManager] getWalletMode] ? NSLocalizedString(@"unlockTipsUnlockAccount", @"解锁帐号") : NSLocalizedString(@"unlockTipsUnlockWallet", @"解锁钱包");
            [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:title
                                                              withTitle:nil
                                                            placeholder:NSLocalizedString(@"unlockTipsPleaseInputWalletPassword", @"请输入钱包密码")
                                                             ispassword:YES
                                                                     ok:NSLocalizedString(@"unlockBtnUnlock", @"解锁") completion:^(NSInteger buttonIndex, NSString *tfvalue)
             {
                 if (buttonIndex != 0){
                     id unlockInfos = [[WalletManager sharedWalletManager] unLock:tfvalue];
                     BOOL unlockSuccess = [[unlockInfos objectForKey:@"unlockSuccess"] boolValue];
                     if (unlockSuccess && checkActivePermission && ![[unlockInfos objectForKey:@"haveActivePermission"] boolValue]){
                         unlockSuccess = NO;
                     }
                     if (unlockSuccess){
                         body(YES);
                     }else{
                         [OrgUtils makeToast:[unlockInfos objectForKey:@"err"]];
                         body(NO);
                     }
                 }else{
                     NSLog(@"User cancel unlock account.");
                     body(NO);
                 }
             }];
        }else{
            body(YES);
        }
    }];
}

/**
 *  确保钱包已经解锁（否则会转到解锁处理）REMARK：首先会确保钱包已经存在，并且需要有资金权限。
 */
- (void)GuardWalletUnlocked:(void (^)(BOOL unlocked))body
{
    [self GuardWalletUnlocked:YES body:body];
}

/**
 *  确保钱包存在（否则会转到导入帐号处理）
 */
- (void)GuardWalletExist:(void (^)())body
{
    if ([[WalletManager sharedWalletManager] isWalletExist]){
        body();
    }else{
        VCImportAccount* vc = [[VCImportAccount alloc] initWithSuccessCallback:^{
            body();
        }];
        [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleLogin", @"登录") backtitle:kVcDefaultBackTitleName];
    }
}

#pragma mark - delay
- (void)delay:(void (^)())body
{
    dispatch_async(dispatch_get_main_queue(), ^{
        body();
    });
}

#pragma mark- debug
- (void)printView:(UIView*)view level:(NSInteger)level
{
    if (!view){
        return;
    }
    NSMutableString* indent = [[NSMutableString alloc] init];
    for (int i = 0; i < level; ++i) {
        [indent appendString:@"\t"];
    }
    NSString* indent2 = [indent copy];
//    [indent release];
    for (UIView* v1 in view.subviews) {
        
        NSLog(@"%@level=%d:%@", indent2, (int)level, v1);
        [self printView:v1 level:level+1];
    }
}


#pragma mark- Orientation

//  IOS5
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return UIInterfaceOrientationIsPortrait(toInterfaceOrientation);
}

//  IOS6 or IOS7
- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

//// Returns interface orientation masks.
//- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
//{
//
//}

#pragma mark- switch theme
- (void)switchTheme
{
    //  REMARK:切换theme时需要特殊处理的就重载该方法
}

#pragma mark- switch language
- (void)switchLanguage
{
    //  REMARK:切换language时需要特殊处理的就重载该方法
}

- (void)reloadTableView:(UITableView*)tableView
{
    if (tableView){
        [tableView reloadData];
    }
}

@end
