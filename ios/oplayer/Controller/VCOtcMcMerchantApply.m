//
//  VCOtcMcMerchantApply.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcMerchantApply.h"
#import "ViewTipsInfoCell.h"
#import "VCSearchNetwork.h"
#import "OrgUtils.h"
#import "OtcManager.h"

enum
{
    kVcNickName = 0,            //  商家昵称
    kVcBtsAccount,              //  主账号
    kVcBakAccount,              //  备账号
    kVcSubmit,                  //  提交申请
    kVcTips,                    //  提示信息
    
    kVcMax
};

@interface VCOtcMcMerchantApply ()
{
    UITableViewBase*        _mainTableView;
    
    MyTextField*            _tf_nickname;
    NSDictionary*           _bak_account;
    
    ViewBlockLabel*         _goto_submit;
    ViewTipsInfoCell*       _cell_tips;
}

@end

@implementation VCOtcMcMerchantApply

-(void)dealloc
{
    _bak_account = nil;
    
    if (_tf_nickname){
        _tf_nickname.delegate = nil;
        _tf_nickname = nil;
    }
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _goto_submit = nil;
    _cell_tips = nil;
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_nickname safeResignFirstResponder];
}

- (id)init
{
    self = [super init];
    if (self) {
        _bak_account = nil;
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
    //  TODO:2.9 lang
    NSString* placeHolderNickName = @"请输入商家昵称";
    _tf_nickname = [self createTfWithRect:[self makeTextFieldRect] keyboard:UIKeyboardTypeDefault placeholder:placeHolderNickName];
    
    //  设置属性颜色等
    _tf_nickname.updateClearButtonTintColor = YES;
    _tf_nickname.textColor = theme.textColorMain;
    _tf_nickname.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderNickName];
    
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
    _goto_submit = [self createCellLableButton:@"申请"];//TODO:otc
    
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:@"【温馨提示】\n申请通过之后平台将为商家分配独立的OTC账号，用于场外交易。\nOTC账号与商家个人账号绑定，商家可通过个人账号控制OTC账号。\n当个人账号丢失时，商家可通过备用账号与平台协作修改OTC账号权限。"];
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
    NSString* str_nickname = _tf_nickname.text;
    
    //  TODO:2.9 lang
    if (!str_nickname || [str_nickname isEqualToString:@""]) {
        [OrgUtils makeToast:@"请输入商家昵称。"];
        return;
    }
    
    if (!_bak_account) {
        [OrgUtils makeToast:@"请选择备用账号。"];
        return;
    }
    
    OtcManager* otc = [OtcManager sharedOtcManager];
    NSString* bts_account = [otc getCurrentBtsAccount];
    NSString* bak_account = [_bak_account objectForKey:@"name"];
    if ([bts_account isEqualToString:bak_account]) {
        [OrgUtils makeToast:@"个人账号和备用账号不能相同。"];
        return;
    }
    
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[otc merchantApply:bts_account bakAccount:bak_account nickName:str_nickname] then:^id(id data) {
                [self hideBlockView];
                //  TODO:2.9 申请成功
                [OrgUtils makeToast:@"提交申请成功，请耐心等待审核。"];
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
    if (textField == _tf_nickname) {
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
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
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
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  TODO:2.9 lang
    switch (indexPath.section) {
        case kVcNickName:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = @"商家昵称";
            cell.textLabel.textColor = theme.textColorMain;
            cell.accessoryView = _tf_nickname;
            cell.showCustomBottomLine = YES;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            return cell;
        }
            break;
        case kVcBtsAccount:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = @"个人账号";
            cell.textLabel.textColor = theme.textColorMain;
            cell.detailTextLabel.text = [[OtcManager sharedOtcManager] getCurrentBtsAccount];
            cell.detailTextLabel.textColor = theme.buyColor;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            return cell;
        }
            break;
        case kVcBakAccount:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.text = @"备用账号";
            cell.textLabel.textColor = theme.textColorMain;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            if (_bak_account){
                cell.detailTextLabel.textColor = theme.textColorMain;//TODO:color
                cell.detailTextLabel.text = [_bak_account objectForKey:@"name"];
            }else{
                cell.detailTextLabel.textColor = theme.textColorGray;
                cell.detailTextLabel.text = @"请选择备用账号";
            }
            return cell;
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
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kVcBakAccount:
            {
                [self resignAllFirstResponder];
                VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAccount callback:^(id account_info) {
                    if (account_info){
                        _bak_account = account_info;
                        [_mainTableView reloadData];
                    }
                }];
                //  TODO:2.9
                [self pushViewController:vc
                                 vctitle:@"备用账号"
                               backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kVcSubmit:
            {
                [self resignAllFirstResponder];
                [self gotoSubmitCore];
            }
                break;
            default:
                break;
        }
    }];
}

@end
