//
//  VCOtcUserAuth.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcUserAuth.h"
#import "OrgUtils.h"

#import "ViewTipsInfoCell.h"
#import "OtcManager.h"
#import "AsyncTaskManager.h"

enum
{
    kVcFormData = 0,            //  表单数据
    kVcSubmit,                  //  提交按钮
    kVcCellTips,                //  提示说明
    
    kVcMax
};

enum
{
    kVcSubNameTitle = 0,
    kVcSubName,                 //  姓名
    
    kVcSubIDNumberTitle,
    kVcSubIDNumber,             //  身份证号
    
    kVcSubPhoneNumberTitle,
    kVcSubPhoneNumber,          //  手机号
    
    kVcSubSmsCode,              //  短信验证码
    
    kVcSubMax
};

@interface VCOtcUserAuth ()
{
    UITableViewBase*        _mainTableView;
    
    UITableViewCellBase*    _cellAssetAvailable;
    UITableViewCellBase*    _cellFinalValue;
    
    MyTextField*            _tf_name;
    MyTextField*            _tf_idnumber;
    MyTextField*            _tf_phonenumber;
    MyTextField*            _tf_smscode;
    
    ViewBlockLabel*         _goto_submit;
    ViewTipsInfoCell*       _cell_tips;
    
    NSInteger               _smsTimerId;
}

@end

@implementation VCOtcUserAuth

-(void)dealloc
{
    //  移除定时器
    [[AsyncTaskManager sharedAsyncTaskManager] removeSecondsTimer:_smsTimerId];
    
    if (_tf_name){
        _tf_name.delegate = nil;
        _tf_name = nil;
    }
    
    if (_tf_idnumber){
        _tf_idnumber.delegate = nil;
        _tf_idnumber = nil;
    }

    if (_tf_phonenumber){
        _tf_phonenumber.delegate = nil;
        _tf_phonenumber = nil;
    }
    
    if (_tf_smscode) {
        _tf_smscode.delegate = nil;
        _tf_smscode = nil;
    }
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    
    _cell_tips = nil;
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_name safeResignFirstResponder];
    [_tf_idnumber safeResignFirstResponder];
    [_tf_phonenumber safeResignFirstResponder];
    [_tf_smscode safeResignFirstResponder];
}

/*
 *  (private) 点击获取验证码
 */
- (void)onRequestSmsCodeButtonClicked:(UIButton*)sender
{
    //  倒计时中
    if ([[AsyncTaskManager sharedAsyncTaskManager] isExistSecondsTimer:_smsTimerId]) {
        return;
    }
    
    id str_phone_num = _tf_phonenumber.text;
    if (![OtcManager checkIsValidPhoneNumber:str_phone_num]){
        [OrgUtils makeToast:NSLocalizedString(@"kOtcRmSubmitTipsInputPhoneNo", @"请输入正确的手机号码。")];
        return;
    }
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  TODO:2.9 配置，短信重发时间间隔。单位：秒。
    NSInteger max_countdown_secs = 60;
    OtcManager* otc = [OtcManager sharedOtcManager];
    [[[otc sendSmsCode:[otc getCurrentBtsAccount] phone:str_phone_num type:eost_id_verify] then:^id(id data) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"kOtcAuthInfoTailerTipsGetSmscodeOK", @"短信发送成功。")];
        //  重发倒计时
        [sender setTitle:[NSString stringWithFormat:NSLocalizedString(@"kOtcAuthInfoTailerBtnGetSmscodeWaitNsec", @"%@秒后重新获取"), @(max_countdown_secs)] forState:UIControlStateNormal];
        _smsTimerId = [[AsyncTaskManager sharedAsyncTaskManager] scheduledSecondsTimer:max_countdown_secs callback:^(NSInteger left_ts) {
            if (left_ts > 0) {
                [sender setTitle:[NSString stringWithFormat:NSLocalizedString(@"kOtcAuthInfoTailerBtnGetSmscodeWaitNsec", @"%@秒后重新获取"), @(left_ts)] forState:UIControlStateNormal];
            } else {
                [sender setTitle:NSLocalizedString(@"kOtcAuthInfoTailerBtnGetSmscode", @"获取验证码") forState:UIControlStateNormal];
            }
        }];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化数据
    _smsTimerId = 0;
    
    //  初始化UI
    NSString* placeHolderName = NSLocalizedString(@"kOtcRmAddPlaceholderRealname", @"请输入您的姓名");
    NSString* placeHolderIdNumber = NSLocalizedString(@"kOtcAuthInfoPlaceholderIdNo", @"请输入身份证号");
    NSString* placeHolderPhoneNumber = NSLocalizedString(@"kOtcAuthInfoPlaceholderPhoneNo", @"请输入手机号码");
    NSString* placeHolderSmscode = NSLocalizedString(@"kOtcAuthInfoPlaceholderSmscode", @"短信验证码");
    CGRect rect = [self makeTextFieldRectFull];
    _tf_name = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderName];
    _tf_idnumber = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderIdNumber];
    _tf_phonenumber = [self createTfWithRect:rect keyboard:UIKeyboardTypePhonePad placeholder:placeHolderPhoneNumber];
    _tf_smscode = [self createTfWithRect:rect keyboard:UIKeyboardTypeNumberPad placeholder:placeHolderSmscode];
    
    //  设置属性颜色等
    _tf_name.showBottomLine = YES;
    _tf_idnumber.showBottomLine = YES;
    _tf_phonenumber.showBottomLine = YES;
    _tf_smscode.showBottomLine = YES;
    
    _tf_name.updateClearButtonTintColor = YES;
    _tf_name.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_name.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderName];
    
    _tf_idnumber.updateClearButtonTintColor = YES;
    _tf_idnumber.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_idnumber.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderIdNumber];
 
    _tf_phonenumber.updateClearButtonTintColor = YES;
    _tf_phonenumber.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_phonenumber.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderPhoneNumber];
    
    _tf_smscode.updateClearButtonTintColor = YES;
    _tf_smscode.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_smscode.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderSmscode];
    //  自动填充短信验证码
    if (@available(iOS 12.0, *)) {
        _tf_smscode.textContentType = UITextContentTypeOneTimeCode;
    }

    //  UI - 短信验证码尾部获取按钮
    UIButton* btnRequestSmsCode = [UIButton buttonWithType:UIButtonTypeCustom];
    btnRequestSmsCode.titleLabel.font = [UIFont systemFontOfSize:13];
    [btnRequestSmsCode setTitle:NSLocalizedString(@"kOtcAuthInfoTailerBtnGetSmscode", @"获取验证码") forState:UIControlStateNormal];
    [btnRequestSmsCode setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
    btnRequestSmsCode.userInteractionEnabled = YES;
    [btnRequestSmsCode addTarget:self
                          action:@selector(onRequestSmsCodeButtonClicked:)
                forControlEvents:UIControlEventTouchUpInside];
    btnRequestSmsCode.frame = CGRectMake(0, 2, 120, 27);
    btnRequestSmsCode.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    //  REMARK：button外再套一层  UIView，不然设置 frame 无效。
    _tf_smscode.rightView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 120, 31)] ruby_apply:^(id obj) {
        [obj addSubview:btnRequestSmsCode];
    }];
    _tf_smscode.rightViewMode = UITextFieldViewModeAlways;
    
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
    
    //  提示
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:NSLocalizedString(@"kOtcAuthInfoCellTips", @"【温馨提示】\n您只有通过了身份认证，才能进行场外交易。\n姓名和身份证号提交后不可更改。")];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    //  提交按钮
    _goto_submit = [self createCellLableButton:NSLocalizedString(@"kOtcRmAddSubmitBtnName", @"提交")];
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
    //  是否开启新用户认证功能判断
    OtcManager* otc = [OtcManager sharedOtcManager];
    assert(otc.server_config);
    id auth_config = [otc.server_config objectForKey:@"auth"];
    if (![[auth_config objectForKey:@"enable"] boolValue]) {
        NSString* msg = [auth_config objectForKey:@"msg"];
        if (!msg || [msg isEqualToString:@""]) {
            msg = NSLocalizedString(@"kOtcEntryDisableDefaultMsg", @"系统维护中，请稍后再试。");
        }
        [OrgUtils makeToast:msg];
        return;
    }
    
    NSString* str_name = _tf_name.text;
    NSString* str_cardno = _tf_idnumber.text;
    NSString* str_phone_num = _tf_phonenumber.text;
    NSString* str_sms_code = _tf_smscode.text;
    
    if (!str_name || [str_name isEqualToString:@""]) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcRmSubmitTipsInputRealname", @"请输入姓名。")];
        return;
    }
    if (![OtcManager checkIsValidChineseCardNo:str_cardno]) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcAuthInfoSubmitTipsInputIdNo", @"请输入正确的身份证号。")];
        return;
    }
    if (![OtcManager checkIsValidPhoneNumber:str_phone_num]) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcRmSubmitTipsInputPhoneNo", @"请输入正确的手机号码。")];
        return;
    }
    if (!str_sms_code || [str_sms_code isEqualToString:@""]) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcAuthInfoSubmitTipsInputSmscode", @"请输入短信验证码。")];
        return;
    }
    
    //  认证
    id args = @{
        @"btsAccount":[otc getCurrentBtsAccount],
        @"idcardNo":str_cardno,
        @"phoneNum":str_phone_num,
        @"realName":str_name,
        @"smscode":str_sms_code,
    };
    
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[otc idVerify:args] then:^id(id data) {
                [self hideBlockView];
                [self showMessageAndClose:NSLocalizedString(@"kOtcAuthInfoSubmitTipsOK", @"认证通过。")];
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
    if (textField == _tf_name) {
        [_tf_idnumber becomeFirstResponder];
    }
    else if (textField == _tf_idnumber) {
        [_tf_phonenumber becomeFirstResponder];
    }else if (textField == _tf_phonenumber) {
        [_tf_smscode becomeFirstResponder];
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
                case kVcSubNameTitle:
                case kVcSubIDNumberTitle:
                case kVcSubPhoneNumberTitle:
                    return 28.0f;
                default:
                    break;
            }
        }
            break;
        case kVcCellTips:
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
    if (indexPath.section == kVcFormData)
    {
        switch (indexPath.row) {
            case kVcSubNameTitle:
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
            case kVcSubName:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                [_mainTableView attachTextfieldToCell:cell tf:_tf_name];
                return cell;
            }
                break;
            case kVcSubIDNumberTitle:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.hideBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kOtcAuthInfoCellLabelTitleIdNo", @"身份证号");
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                return cell;
            }
                break;
            case kVcSubIDNumber:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                [_mainTableView attachTextfieldToCell:cell tf:_tf_idnumber];
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            }
                break;
            case kVcSubPhoneNumberTitle:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.hideBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kOtcAuthInfoCellLabelTitleContact", @"联系方式");
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                return cell;
            }
                break;
            case kVcSubPhoneNumber:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                [_mainTableView attachTextfieldToCell:cell tf:_tf_phonenumber];
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            }
                break;
            case kVcSubSmsCode:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                [_mainTableView attachTextfieldToCell:cell tf:_tf_smscode];
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            }
                break;
            default:
                assert(false);
                break;
        }
    }else if (indexPath.section == kVcCellTips){
        return _cell_tips;
    } else {
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.hideBottomLine = YES;
        cell.hideTopLine = YES;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_goto_submit cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
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
