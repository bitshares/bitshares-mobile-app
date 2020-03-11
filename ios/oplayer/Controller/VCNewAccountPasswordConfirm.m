//
//  VCNewAccountPasswordConfirm.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
//#import <QuartzCore/QuartzCore.h>

#import "VCNewAccountPasswordConfirm.h"
#import "ViewAdvTextFieldCell.h"

enum
{
    kVcFormData = 0,
    kVcSubmit,
    
    kVcMax,
};

enum
{
    kVcSubAccountName = 0,  //  当前账号
    kVcSubConfirmPassword,  //  确认密码
    
    kVcSubMax
};

@interface VCNewAccountPasswordConfirm ()
{
    WsPromiseObject*        _result_promise;
//    NSDictionary*           _url_hash;
    
    UITableView *           _mainTableView;
    
    ViewAdvTextFieldCell*   _cell_account;
    ViewAdvTextFieldCell*   _cell_confirm_password;
    
    ViewBlockLabel*         _lbSubmit;
}

@end

@implementation VCNewAccountPasswordConfirm

-(void)dealloc
{
    _lbSubmit = nil;
    
    _cell_account = nil;
    _cell_confirm_password = nil;
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    
    _result_promise = nil;
}

- (id)initWithUrlHash:(NSDictionary*)url_hash result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
//        _url_hash = url_hash;
        _result_promise = result_promise;
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //  TODO:5.0 lang
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    _cell_account = [[ViewAdvTextFieldCell alloc] initWithTitle:@"当前账号"
                                                    placeholder:@"当前账号名"];
    _cell_account.mainTextfield.text = [[[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"name"];
    
    //  TODO:5.0 输入中文
    _cell_confirm_password = [[ViewAdvTextFieldCell alloc] initWithTitle:@"验证密码"
                                                   placeholder:@"请输入上一步生成的密码"];
    _cell_confirm_password.mainTextfield.keyboardType = UIKeyboardTypeURL;
    
    //  UI - 主列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    _lbSubmit = [self createCellLableButton:@"修改"];
}

- (void)endInput
{
    [super endInput];
    [_cell_account endInput];
    [_cell_confirm_password endInput];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self endInput];
}



/*
 *  (private) 确定添加
 */
- (void)onSubmitClicked
{
    [self endInput];
    
    NSString* account_name = [NSString trim:_cell_account.mainTextfield.text];
    NSString* confirm_password = [NSString trim:_cell_confirm_password.mainTextfield.text];
    
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

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    //  TODO:5.0 未完成
    [self endInput];
    return YES;
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcFormData) {
        switch (indexPath.row) {
            case kVcSubAccountName:
                return _cell_account.cellHeight;
            case kVcSubConfirmPassword:
                return _cell_confirm_password.cellHeight;
            default:
                break;
        }
    }
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcFormData){
        return kVcSubMax;
    }else{
        return 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == kVcSubmit){
        return tableView.sectionFooterHeight;
    }else{
        return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcFormData)
    {
        switch (indexPath.row) {
            case kVcSubAccountName:
                return _cell_account;
            case kVcSubConfirmPassword:
                return _cell_confirm_password;
            default:
                assert(false);
                break;
        }
    }else{
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.hideBottomLine = YES;
        cell.hideTopLine = YES;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_lbSubmit cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
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
