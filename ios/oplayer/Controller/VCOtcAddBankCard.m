//
//  VCOtcAddBankCard.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcAddBankCard.h"
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
    
    kVcSubBankCardNoTitle,
    kVcSubBankCardNo,           //  银行卡号
    
    kVcSubBankPhoneNumTitle,
    kVcSubBankPhoneNum,         //  预留手机号
    
    kVcSubMax
};

@interface VCOtcAddBankCard ()
{
    WsPromiseObject*        _result_promise;
    NSDictionary*           _auth_info;
    UITableViewBase*        _mainTableView;
    
    UITableViewCellBase*    _cellAssetAvailable;
    UITableViewCellBase*    _cellFinalValue;
    
    MyTextField*            _tf_username;
    MyTextField*            _tf_bankcardno;
    MyTextField*            _tf_bankphonenumber;
    
    ViewBlockLabel*         _goto_submit;
    ViewTipsInfoCell*       _cell_tips;
}

@end

@implementation VCOtcAddBankCard

-(void)dealloc
{
    if (_tf_username){
        _tf_username.delegate = nil;
        _tf_username = nil;
    }
    
    if (_tf_bankcardno){
        _tf_bankcardno.delegate = nil;
        _tf_bankcardno = nil;
    }
    
    if (_tf_bankphonenumber){
        _tf_bankphonenumber.delegate = nil;
        _tf_bankphonenumber = nil;
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
    [_tf_bankcardno safeResignFirstResponder];
    [_tf_bankphonenumber safeResignFirstResponder];
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
    NSString* placeHolderBankCardNo = NSLocalizedString(@"kOtcRmAddPlaceholderBankCardNo", @"请输入银行卡号");
    NSString* placeHolderBankPhoneNum = NSLocalizedString(@"kOtcRmAddPlaceholderBankPhoneNo", @"请输入银行预留手机号");
    CGRect rect = [self makeTextFieldRectFull];
    _tf_username = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderUserName];
    _tf_bankcardno = [self createTfWithRect:rect keyboard:UIKeyboardTypeNumberPad placeholder:placeHolderBankCardNo];
    _tf_bankphonenumber = [self createTfWithRect:rect keyboard:UIKeyboardTypePhonePad placeholder:placeHolderBankPhoneNum];
    
    //  初始化值
    NSString* name = [_auth_info objectForKey:@"realName"];
    if (name && name.length > 0) {
        _tf_username.text = name;
        _tf_username.userInteractionEnabled = NO;
    }
    
    //  设置属性颜色等
    _tf_username.showBottomLine = YES;
    _tf_bankcardno.showBottomLine = YES;
    _tf_bankphonenumber.showBottomLine = YES;
    
    _tf_username.updateClearButtonTintColor = YES;
    _tf_username.textColor = theme.textColorMain;
    
    _tf_username.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderUserName];
    _tf_bankcardno.updateClearButtonTintColor = YES;
    _tf_bankcardno.textColor = theme.textColorMain;
    _tf_bankcardno.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderBankCardNo];
    
    _tf_bankphonenumber.updateClearButtonTintColor = YES;
    _tf_bankphonenumber.textColor = theme.textColorMain;
    _tf_bankphonenumber.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderBankPhoneNum];
    
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
    
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:NSLocalizedString(@"kOtcRmAddCellTipsBankcard", @"【温馨提示】\n请务必使用您本人的银行卡。")];
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
    NSString* str_realname = _tf_username.text;
    NSString* str_bankno = _tf_bankcardno.text;
    NSString* str_phoneno = _tf_bankphonenumber.text;
    
    if (!str_realname || [str_realname isEqualToString:@""]) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcRmSubmitTipsInputRealname", @"请输入姓名。")];
        return;
    }
    if (!str_bankno || [str_bankno isEqualToString:@""]) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcRmSubmitTipsInputBankcardNo", @"请输入有效的银行卡号。")];
        return;
    }
    if (![OtcManager checkIsValidPhoneNumber:str_phoneno]) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcRmSubmitTipsInputPhoneNo", @"请输入正确的手机号码。")];
        return;
    }
    
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            OtcManager* otc = [OtcManager sharedOtcManager];
            id args = @{
                @"account":str_bankno,
                @"btsAccount":[otc getCurrentBtsAccount],
                @"qrCode":@"",                  //  for alipay & wechat pay
                @"realName":str_realname,
                @"remark":@"",                  //  for bank card
                @"reservePhone":str_phoneno,    //  for bank card
                @"type":@(eopmt_bankcard)
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
        [_tf_bankcardno becomeFirstResponder];
    }
    else if (textField == _tf_bankcardno) {
        [_tf_bankphonenumber becomeFirstResponder];
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
                case kVcSubBankCardNoTitle:
                case kVcSubBankPhoneNumTitle:
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
                case kVcSubBankCardNoTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kOtcRmAddCellLabelTitleBankCardNo", @"银行卡号");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;
                }
                    break;
                case kVcSubBankCardNo:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    [_mainTableView attachTextfieldToCell:cell tf:_tf_bankcardno];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                case kVcSubBankPhoneNumTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kOtcRmAddCellLabelTitleBankPhoneNo", @"预留手机号");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;
                }
                    break;
                case kVcSubBankPhoneNum:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    [_mainTableView attachTextfieldToCell:cell tf:_tf_bankphonenumber];
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
