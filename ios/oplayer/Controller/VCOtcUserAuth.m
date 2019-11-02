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

enum
{
    kVcFormData = 0,            //  表单数据
    kVcSubmit,                  //  提币按钮
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
}

@end

@implementation VCOtcUserAuth

-(void)dealloc
{
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

- (void)onRequestSmsCodeButtonClicked:(UIButton*)sender
{
    //  TODO:otc
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化UI
    //  TODO:otc
    NSString* placeHolderName = @"请输入您的姓名";
    NSString* placeHolderIdNumber = @"请输入身份证号";
    NSString* placeHolderPhoneNumber =  @"请输入手机号码";
    NSString* placeHolderSmscode = @"短信验证码";
    CGRect rect = [self makeTextFieldRectFull];
    _tf_name = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderName];
    _tf_idnumber = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderIdNumber];
    _tf_phonenumber = [self createTfWithRect:rect keyboard:UIKeyboardTypePhonePad placeholder:placeHolderPhoneNumber];
    _tf_smscode = [self createTfWithRect:rect keyboard:UIKeyboardTypeDecimalPad placeholder:placeHolderSmscode];
    
    //  设置属性颜色等
    _tf_name.showBottomLine = YES;
    _tf_idnumber.showBottomLine = YES;
    _tf_phonenumber.showBottomLine = YES;
    _tf_smscode.showBottomLine = YES;
    
    _tf_name.updateClearButtonTintColor = YES;
    _tf_name.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_name.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderName
                                                                        attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                     NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tf_idnumber.updateClearButtonTintColor = YES;
    _tf_idnumber.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_idnumber.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderIdNumber
                                                                       attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                    NSFontAttributeName:[UIFont systemFontOfSize:17]}];
 
    _tf_phonenumber.updateClearButtonTintColor = YES;
    _tf_phonenumber.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_phonenumber.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderPhoneNumber
                                                                     attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                  NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    _tf_smscode.updateClearButtonTintColor = YES;
    _tf_smscode.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_smscode.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderSmscode
                                                                     attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                  NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    //  自动填充短信验证码
    if (@available(iOS 12.0, *)) {
        _tf_smscode.textContentType = UITextContentTypeOneTimeCode;
    }
    
    //  绑定输入事件（限制输入） TODO:otc
    [_tf_idnumber addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    //  UI - 短信验证码尾部获取按钮
    UIButton* btnRequestSmsCode = [UIButton buttonWithType:UIButtonTypeSystem];
    btnRequestSmsCode.titleLabel.font = [UIFont systemFontOfSize:13];
    [btnRequestSmsCode setTitle:@"获取验证码" forState:UIControlStateNormal];//TODO:otc
    [btnRequestSmsCode setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
    btnRequestSmsCode.userInteractionEnabled = YES;
    [btnRequestSmsCode addTarget:self
                          action:@selector(onRequestSmsCodeButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnRequestSmsCode.frame = CGRectMake(6, 2, 80, 27);
    _tf_smscode.rightView = btnRequestSmsCode;
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
    
    //  提示 TODO:otc wenzi
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:@"【温馨提示】\n您只有通过了身份认证，才能进行场外交易。\n目前仅支持中国大陆地区进行身份认证。姓名和身份证号提交后不可更改。"];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    //  提交按钮
    _goto_submit = [self createCellLableButton:@"提交"];//TODO:otc
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
    //  TODO:otc
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    return YES;//TODO:otc
}

- (void)onTextFieldDidChange:(UITextField*)textField
{
    //  TODO:otc
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
                cell.textLabel.text = @"姓名";//TODO:otc
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
                cell.textLabel.text = @"身份证号";//TODO:otc
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
                cell.textLabel.text = @"联系方式";//TODO:otc
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
                [_mainTableView attachTextfieldToCell:cell tf:_tf_smscode];//TODO:
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
