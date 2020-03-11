//
//  VCNewAccountPassword.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCNewAccountPassword.h"
#import "ViewTipsInfoCell.h"
#import "ViewNewPasswordCell.h"
#import "VCNewAccountPasswordConfirm.h"

enum
{
    kVcNewPassword = 0,
    kVcSubmit,
    kVcCellTips,
    
    kVcMax
};

enum
{
    kVcSubNewPasswordTitle = 0,
    kVcSubNewPasswordContent,
    
    kVcSubMax,
};

@interface VCNewAccountPassword ()
{
    UITableView *                   _mainTableView;
    UITableViewCellBase*            _cellTitle;
    ViewNewPasswordCell*            _passwordContent;
    
    EBitsharesAccountPasswordLang   _currPasswordLang;
    
    ViewBlockLabel*                 _lbSubmit;
    ViewTipsInfoCell*               _cellTips;
}

@end

@implementation VCNewAccountPassword

-(void)dealloc
{
    _cellTitle = nil;
    _lbSubmit = nil;
    _cellTips = nil;
    _passwordContent = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
        _currPasswordLang = ebap_lang_zh;//TODO:5.0 根据当前语言决定
    }
    return self;
}

/*
 *  (private) 切换密码语言。
 */
- (void)onSwitchPasswordLangButtonClicked:(UIButton*)sender
{
    //  切换
    if (_currPasswordLang == ebap_lang_zh) {
        _currPasswordLang = ebap_lang_en;
    } else {
        _currPasswordLang = ebap_lang_zh;
    }
    //  刷新切换按钮
    UIButton* btn = (UIButton*)_cellTitle.accessoryView;
    assert(btn);
    [btn updateTitleWithoutAnimation:[self switchPasswordLangButtonString]];
    //  TODO:5.0 随机生成密码
//    if (_currPasswordLang == ebap_lang_zh) {
//
//    }
    [_passwordContent updateWithNewContent:@"" lang:_currPasswordLang];
    [_mainTableView reloadData];
}

- (NSString*)switchPasswordLangButtonString
{
    //  TODO:5.0 lang
    return _currPasswordLang == ebap_lang_zh ? @"切换英文密码" : @"切换中文密码";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    _cellTitle = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellTitle.backgroundColor = [UIColor clearColor];
    _cellTitle.hideBottomLine = YES;
    _cellTitle.accessoryType = UITableViewCellAccessoryNone;
    _cellTitle.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellTitle.textLabel.text = @"您的新密码";
    _cellTitle.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellTitle.textLabel.textColor = theme.textColorMain;
    
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.titleLabel.font = [UIFont systemFontOfSize:13];
    [btn setTitle:[self switchPasswordLangButtonString] forState:UIControlStateNormal];
    [btn setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:@selector(onSwitchPasswordLangButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    btn.frame = CGRectMake(0, 0, 130, 31);
    _cellTitle.accessoryView = btn;
    
//    UIButton* btnTips = [UIButton buttonWithType:UIButtonTypeCustom];
//    UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];
//    CGSize btn_size = btn_image.size;
//    [btnTips setBackgroundImage:btn_image forState:UIControlStateNormal];
//    btnTips.userInteractionEnabled = YES;
//    [btnTips addTarget:self action:@selector(onTipButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
//    btnTips.frame = CGRectMake(0, (44 - btn_size.height) / 2, btn_size.width, btn_size.height);
//    btnTips.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
//    btnTips.tag = tag;
//    return btnTips;
    
    
    //  UI - 当前密码 TODO:5.0
    _passwordContent = [[ViewNewPasswordCell alloc] init];
    [_passwordContent updateWithNewContent:@"" lang:_currPasswordLang];
    
    //  UI - 主列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    _lbSubmit = [self createCellLableButton:@"下一步"];
    
    //  提示 TODO:5.0 lang 文案需要调整 16 %@
    _cellTips = [[ViewTipsInfoCell alloc] initWithText:@"【温馨提示】\n请勿复制、拍照、截图。\n请使用纸笔按照从左到右、从上到下的顺序依次记录以上 16 个字符组成的密码，并妥善保存。丢失后将无法找回。"];
    _cellTips.hideBottomLine = YES;
    _cellTips.hideTopLine = YES;
    _cellTips.backgroundColor = [UIColor clearColor];
}

/*
 *  (private) 转到下一步
 */
- (void)onSubmitClicked
{
    //  TODO:5.0 args, password
    VCNewAccountPasswordConfirm* vc = [[VCNewAccountPasswordConfirm alloc] init];
    [self pushViewController:vc vctitle:@"验证密码" backtitle:kVcDefaultBackTitleName];
    
    //    [self endInput];
    //
    //    NSString* name = [NSString trim:_cell_apiname.mainTextfield.text];
    //    NSString* url = [NSString trim:_cell_apiurl.mainTextfield.text];
    //
    //    if (!name || [name isEqualToString:@""]) {
    //        [OrgUtils makeToast:NSLocalizedString(@"kSettingNewApiSubmitTipsPleaseInputNodeName", @"请输入节点名称。")];
    //        return;
    //    }
    //
    //    if (!url || [url isEqualToString:@""]) {
    //        [OrgUtils makeToast:NSLocalizedString(@"kSettingNewApiSubmitTipsPleaseInputNodeURL", @"请输入有效的节点地址。")];
    //        return;
    //    }
    //
    //    if ([_url_hash objectForKey:url]) {
    //        [OrgUtils makeToast:NSLocalizedString(@"kSettingNewApiSubmitTipsURLAlreadyExist", @"当前节点已存在。")];
    //        return;
    //    }
    //
    //    id node = @{@"location":name, @"url":url, @"_is_custom":@YES};
    //    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //    [[GrapheneConnection checkNodeStatus:node max_retry_num:0 connect_timeout:10 return_connect_obj:NO] then:^id(id node_status) {
    //        [self hideBlockView];
    //        if ([[node_status objectForKey:@"connected"] boolValue]) {
    //            //  TODO: 以后也许考虑添加非mainnet等api节点。
    //            id chain_id = [[node_status objectForKey:@"chain_properties"] objectForKey:@"chain_id"];
    //            if (chain_id && [chain_id isEqualToString:@BTS_NETWORK_CHAIN_ID]) {
    //                [OrgUtils makeToast:NSLocalizedString(@"kSettingNewApiSubmitTipsOK", @"添加成功。")];
    //                //  返回上一个界面并刷新
    //                if (_result_promise) {
    //                    [_result_promise resolve:node];
    //                }
    //                [self closeOrPopViewController];
    //            } else {
    //                [OrgUtils makeToast:NSLocalizedString(@"kSettingNewApiSubmitTipsNotBitsharesMainnetNode", @"该节点不是比特股主网节点，请重新输入。")];
    //            }
    //        } else {
    //            [OrgUtils makeToast:NSLocalizedString(@"kSettingNewApiSubmitTipsConnectedFailed", @"连接失败，请重新检测URL有效性。")];
    //        }
    //        return nil;
    //    }];
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcNewPassword:
        {
            if (indexPath.row == kVcSubNewPasswordContent) {
                return 8 + 28 * 2 + 8;
            }
        }
            break;
        case kVcCellTips:
            return [_cellTips calcCellDynamicHeight:tableView.layoutMargins.left];
            
        default:
            break;
    }
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcNewPassword:
            return kVcSubMax;
        default:
            break;
    }
    return 1;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcNewPassword:
        {
            switch (indexPath.row) {
                case kVcSubNewPasswordTitle:
                    return _cellTitle;
                    
                case kVcSubNewPasswordContent:
                    return _passwordContent;
                    
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
            [self addLabelButtonToCell:_lbSubmit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcCellTips:
            return _cellTips;
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
        if (indexPath.section == kVcSubmit){
            [self onSubmitClicked];
        }
    }];
}

@end
