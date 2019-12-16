//
//  VCOtcAddAlipay.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcAddAlipay.h"
#import "ViewTipsInfoCell.h"
#import "OrgUtils.h"
#import "OtcManager.h"

enum
{
    kVcFormData = 0,            //  表单数据
    kVcSubmit,                  //  保存按钮
    kVcTips,                    //  提示信息
    
    kVcMax
};

enum
{
    kVcSubUserNameTitle = 0,
    kVcSubUserName,             //  姓名
    
    kVcSubAccountIDTitle,
    kVcSubAccountID,            //  账号
    
    kVcSubMax
};

@interface VCOtcAddAlipay ()
{
    WsPromiseObject*        _result_promise;
    NSDictionary*           _auth_info;
    UITableViewBase*        _mainTableView;
    
    UITableViewCellBase*    _cellAssetAvailable;
    UITableViewCellBase*    _cellFinalValue;
    
    MyTextField*            _tf_username;
    MyTextField*            _tf_account_id;
    
    ViewBlockLabel*         _goto_submit;
    ViewTipsInfoCell*       _cell_tips;
}

@end

@implementation VCOtcAddAlipay

-(void)dealloc
{
    if (_tf_username){
        _tf_username.delegate = nil;
        _tf_username = nil;
    }
    
    if (_tf_account_id){
        _tf_account_id.delegate = nil;
        _tf_account_id = nil;
    }
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _auth_info = nil;
    _result_promise = nil;
    _cell_tips = nil;
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_username safeResignFirstResponder];
    [_tf_account_id safeResignFirstResponder];
}

- (id)initWithAuthInfo:(id)auth_info result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
        _result_promise = result_promise;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  背景颜色
    self.view.backgroundColor = theme.appBackColor;
    
    //  初始化UI
    NSString* placeHolderUserName = NSLocalizedString(@"kOtcRmAddPlaceholderRealname", @"请输入您的姓名");
    NSString* placeHolderAccountID = NSLocalizedString(@"kOtcRmAddPlaceholderAccountName", @"请输入账号");
    CGRect rect = [self makeTextFieldRectFull];
    _tf_username = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderUserName];
    _tf_account_id = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderAccountID];

    //  初始化值
    NSString* name = [_auth_info objectForKey:@"realName"];
    if (name && name.length > 0) {
        _tf_username.text = name;
        _tf_username.userInteractionEnabled = NO;
    }
    
    //  设置属性颜色等
    _tf_username.showBottomLine = YES;
    _tf_account_id.showBottomLine = YES;

    _tf_username.updateClearButtonTintColor = YES;
    _tf_username.textColor = theme.textColorMain;
    
    _tf_username.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderUserName];
    _tf_account_id.updateClearButtonTintColor = YES;
    _tf_account_id.textColor = theme.textColorMain;
    _tf_account_id.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderAccountID];
 
    //  UI - 主表格
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.hideAllLines = YES;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  空白区域点击
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    //  提交按钮
    _goto_submit = [self createCellLableButton:NSLocalizedString(@"kOtcRmAddSubmitBtnName", @"提交")];
    
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:NSLocalizedString(@"kOtcRmAddCellTipsAlipay", @"【温馨提示】\n请务必使用您本人的实名账号。")];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

/**
 *  事件 - 用户点击提交按钮
 */
-(void)gotoSubmitCore
{
    NSString* str_name = _tf_username.text;
    NSString* str_account = _tf_account_id.text;
    
    if (!str_name || [str_name isEqualToString:@""]) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcRmSubmitTipsInputRealname", @"请输入姓名。")];
        return;
    }
    
    //  账号有效性检测
    if (!str_account || [str_account isEqualToString:@""]) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcRmSubmitTipsInputValidAccount", @"请输入账号。")];
        return;
    }
    
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            OtcManager* otc = [OtcManager sharedOtcManager];
            id args = @{
                @"account":str_account,
                @"btsAccount":[otc getCurrentBtsAccount],
                @"qrCode":@"",          //  for alipay & wechat pay TODO:3.0 暂时不支持二维码
                @"realName":str_name,
                @"remark":@"",          //  for bank card
                @"reservePhone":@"",    //  for bank card
                @"type":@(eopmt_alipay)
            };
            [[[otc addPaymentMethods:args] then:^id(id data) {
                [self hideBlockView];
                [OrgUtils makeToast:NSLocalizedString(@"kOtcRmSubmitTipsOK", @"添加成功。")];
                //  返回上一个界面并刷新
                if (_result_promise) {
                    [_result_promise resolve:@YES];
                }
                [self closeOrPopViewController];
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                [otc showOtcError:error];
                return nil;
            }];
        }
    }];
}

#pragma mark- UITextFieldDelegate delegate method
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _tf_username) {
        [_tf_account_id becomeFirstResponder];
    } else {
        [self resignAllFirstResponder];
    }
    return YES;
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcFormData)
        return kVcSubMax;
    else
        return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcFormData:
        {
            switch (indexPath.row) {
                case kVcSubUserNameTitle:
                case kVcSubAccountIDTitle:
                    return 28.0f;
                default:
                    break;
            }
        }
            break;
        case kVcTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    //  默认值
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section != kVcSubmit){
        return 0.01f;
    }
    return 20.0f;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcFormData:
        {
            switch (indexPath.row) {
                case kVcSubUserNameTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kOtcRmAddCellLabelTitleName", @"姓名");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;
                }
                    break;
                case kVcSubUserName:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    [_mainTableView attachTextfieldToCell:cell tf:_tf_username];
                    return cell;
                }
                    break;
                case kVcSubAccountIDTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kOtcRmAddCellLabelTitleAccount", @"账号");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;
                }
                    break;
                case kVcSubAccountID:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    [_mainTableView attachTextfieldToCell:cell tf:_tf_account_id];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                default:
                    assert(false);
                    break;
            }
        }
            break;
        case kVcSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_goto_submit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcTips:
            return _cell_tips;
        default:
            break;
    }
    
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == kVcSubmit){
        //  表单行为按钮点击
        [self resignAllFirstResponder];
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            [self delay:^{
                [self gotoSubmitCore];
            }];
        }];
    }
}

@end
