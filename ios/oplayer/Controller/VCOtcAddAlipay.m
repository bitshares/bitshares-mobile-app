//
//  VCOtcAddAlipay.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcAddAlipay.h"
#import "OrgUtils.h"

enum
{
    kVcFormData = 0,            //  表单数据
    kVcSubmit,                  //  保存按钮
    
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
    NSDictionary*           _auth_info;
    UITableViewBase*        _mainTableView;
    
    UITableViewCellBase*    _cellAssetAvailable;
    UITableViewCellBase*    _cellFinalValue;
    
    MyTextField*            _tf_username;
    MyTextField*            _tf_account_id;
    
    ViewBlockLabel*         _goto_submit;
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
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_username safeResignFirstResponder];
    [_tf_account_id safeResignFirstResponder];
}

- (id)initWithAuthInfo:(id)auth_info
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
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
    //  TODO:otc
    NSString* placeHolderUserName = @"请输入您的姓名";
    NSString* placeHolderAccountID = @"请输入账号";
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
    _tf_username.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderUserName
                                                                        attributes:@{NSForegroundColorAttributeName:theme.textColorGray,
                                                                                     NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tf_account_id.updateClearButtonTintColor = YES;
    _tf_account_id.textColor = theme.textColorMain;
    _tf_account_id.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderAccountID
                                                                       attributes:@{NSForegroundColorAttributeName:theme.textColorGray,
                                                                                    NSFontAttributeName:[UIFont systemFontOfSize:17]}];
 
    //  绑定输入事件（限制输入） TODO:otc
    [_tf_account_id addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
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
            case kVcSubUserNameTitle:
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
                cell.textLabel.text = @"账号";//TODO:otc
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
