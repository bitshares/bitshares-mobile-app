//
//  VCMemberShip.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCMemberShip.h"
#import "WalletManager.h"
#import "VCBackupWallet.h"

#import "OrgUtils.h"
#import "AppCacheManager.h"

enum
{
    kVcBasicInfo = 0,           //  基本信息
    kVcCommit,                  //  升级按钮
    
    kVcMax
};

enum
{
    kVcSubID = 0,               //  帐号ID
    kVcSubAccount,              //  帐号名字
    kVcSubMemberStatus,         //  会员状态
    kVcSubRefCode,              //  我的推荐码
    //    kVcSubMemberDesc,           //  会员返现描述//TODO:2.5考虑完善改进会员用途展示
    
    kVcSubBasicInfoMax
};

@interface VCMemberShip ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableView*            _mainTableView;
    
    ViewBlockLabel*         _lbCommit;
    
    BOOL                    _bIsLifetimeMemberShip;
    NSString*               _myReferrerCode;
}

@end

@implementation VCMemberShip

- (void)dealloc
{
    _myReferrerCode = nil;
    _lbCommit = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _owner = nil;
}

- (id)initWithOwner:(VCBase*)owner
{
    self = [super init];
    if (self) {
        _owner = owner;
        _myReferrerCode = nil;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    assert([[WalletManager sharedWalletManager] isWalletExist]);
    [self _refreshMemberShipStatus];
    
	// Do any additional setup after loading the view.
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kAccountBtnUpgradeToLifetimeMember", @"升级终身会员")];
}

- (void)_refresh_ui
{
    [self _refreshMemberShipStatus];
    [_mainTableView reloadData];
}

- (NSString*)_encodeMyRefCode:(NSString*)account_id
{
    assert(account_id);
    id uid = [[account_id componentsSeparatedByString:@"."] lastObject];
    //  base64 编码
    return [[uid dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
}

- (void)_refreshMemberShipStatus
{
    id account_info = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(account_info);
    if ([OrgUtils isBitsharesVIP:[account_info objectForKey:@"membership_expiration_date"]]){
        _bIsLifetimeMemberShip = YES;
        _myReferrerCode = [self _encodeMyRefCode:account_info[@"id"]];
    }else{
        _bIsLifetimeMemberShip = NO;
        _myReferrerCode = nil;
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_bIsLifetimeMemberShip){
        //  no upgrade button
        return kVcMax - 1;
    }
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcBasicInfo:
            return kVcSubBasicInfoMax;
        default:
            return 1;
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //TODO:2.5考虑完善改进会员用途展示
//    if (indexPath.section == kVcBasicInfo && indexPath.row == kVcSubMemberDesc){
//        return 24.0f;
//    }
    return tableView.rowHeight;
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
        case kVcCommit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;

            id account_info = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
            assert(account_info);
            switch (indexPath.row) {
                case kVcSubID:
                    cell.textLabel.text = @"ID";
                    cell.detailTextLabel.text = [account_info objectForKey:@"id"];
                    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                    break;
                case kVcSubAccount:
                    cell.textLabel.text = NSLocalizedString(@"kAccLabelAccount", @"账号");
                    cell.detailTextLabel.text = [account_info objectForKey:@"name"];
                    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                    break;
                case kVcSubMemberStatus:
                {
                    cell.textLabel.text = NSLocalizedString(@"kAccountMembershipStatus", @"状态");
                    if (_bIsLifetimeMemberShip){
                        cell.detailTextLabel.text = NSLocalizedString(@"kLblMembershipLifetime", @"终身会员");
                    }else{
                        cell.detailTextLabel.text = NSLocalizedString(@"kLblMembershipBasic", @"普通会员");
                    }
                }
                    break;
                case kVcSubRefCode:
                {
                    cell.textLabel.text = NSLocalizedString(@"kAccountMembershipMyRefCode", @"我的推荐码");
                    if (_myReferrerCode){
                        cell.selectionStyle = UITableViewCellSelectionStyleGray;
                        cell.detailTextLabel.text = _myReferrerCode;
                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
                    }else{
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.detailTextLabel.text = NSLocalizedString(@"kAccountMembershipNoRefCode", @"无");
                    }
                }
                    break;
//                case kVcSubMemberDesc://TODO:2.5考虑完善改进会员用途展示
//                    cell.showCustomBottomLine = NO;
//                    if (_bIsLifetimeMemberShip){
//                        cell.detailTextLabel.text = NSLocalizedString(@"kAccountUpgradeTipsMember", @"尊敬的终身会员，您已享受80%的手续费返现奖励。");
//                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
//                    }else{
//                        cell.detailTextLabel.text = NSLocalizedString(@"kAccountUpgradeTipsNotMember", @"现在升级终身会员，立享80%手续费返现奖励。");
//                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
//                    }
//                    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
//                    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
//                    break;
                default:
                    break;
            }
            
            return cell;
        }
            break;
    }
    //  not reached
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        UIViewController* vc = nil;
        switch (indexPath.section)
        {
            case kVcCommit:
            {
                if (indexPath.row == 0){
                    [self gotoUpgradeToLifetimeMember];
                }
            }
                break;
            default:
            {
                if (indexPath.row == kVcSubRefCode && _myReferrerCode){
                    [UIPasteboard generalPasteboard].string = [_myReferrerCode copy];
                    [OrgUtils makeToast:NSLocalizedString(@"kAccountMembershipMyRefCodeCopyOK", @"推荐码已复制")];
                }
            }
                break;
        }
        if (vc){
            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        }
    }];
}

#pragma mark- UIActionSheetDelegate

- (void)gotoUpgradeToLifetimeMemberCore:(id)op_data fee_item:(id)fee_item account:(id)account_data
{
    assert(op_data);
    assert(fee_item);
    assert(account_data);
    
    id m_opdata = [op_data mutableCopy];
    [m_opdata setObject:fee_item forKey:@"fee"];
    op_data = [m_opdata copy];
    
    id account_id = account_data[@"id"];
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [_owner GuardProposalOrNormalTransaction:ebo_account_upgrade
                       using_owner_authority:NO
                    invoke_proposal_callback:NO
                                      opdata:op_data
                                   opaccount:account_data
                                        body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
         assert(!isProposal);
         //  请求网络广播
         [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
         [[[[BitsharesClientManager sharedBitsharesClientManager] accountUpgrade:op_data] then:(^id(id data) {
             //  升级成功、继续请求、刷新界面。
             [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_id] then:(^id(id full_data) {
                 [_owner hideBlockView];
                 // 升级会员成功，保存新数据。
                 assert(full_data && ![full_data isKindOfClass:[NSNull class]]);
                 [[AppCacheManager sharedAppCacheManager] updateWalletAccountInfo:full_data];
                 // 刷新界面
                 [self _refresh_ui];
                 [OrgUtils makeToast:NSLocalizedString(@"kAccountUpgradeMemberSubmitTxFullOK", @"升级终身会员成功。")];
                 //  [统计]
                 [OrgUtils logEvents:@"txUpgradeToLifetimeMemberFullOK" params:@{@"account":account_id}];
                 return nil;
             })] catch:(^id(id error) {
                 [self hideBlockView];
                 [OrgUtils makeToast:NSLocalizedString(@"kAccountUpgradeMemberSubmitTxOK", @"升级终身会员成功，但刷新界面失败，请稍后再试。")];
                 //  [统计]
                 [OrgUtils logEvents:@"txUpgradeToLifetimeMemberOK" params:@{@"account":account_id}];
                 return nil;
             })];
             return nil;
         })] catch:(^id(id error) {
             [_owner hideBlockView];
             [OrgUtils showGrapheneError:error];
             //  [统计]
             [OrgUtils logEvents:@"txUpgradeToLifetimeMemberFailed" params:@{@"account":account_id}];
             return nil;
         })];
     }];
}

- (void)gotoUpgradeToLifetimeMember
{
    id account_info = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(account_info);
    
    id op_data = @{
                   @"fee":@{@"amount":@0, @"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID},
                   @"account_to_upgrade":account_info[@"id"],
                   @"upgrade_to_lifetime_member":@YES,
                   };

    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[BitsharesClientManager sharedBitsharesClientManager] calcOperationFee:ebo_account_upgrade opdata:op_data] then:(^id(id fee_price_item) {
        [_owner hideBlockView];
        NSString* price = [OrgUtils formatAssetAmountItem:fee_price_item];
        [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:[NSString stringWithFormat:NSLocalizedString(@"kAccountUpgradeMemberCostAsk", @"升级终身会员需要花费 %@，是否继续？"), price]
                                                               withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                              completion:^(NSInteger buttonIndex)
         {
             if (buttonIndex == 1)
             {
                 //  --- 检测合法 执行请求 ---
                 [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                     if (unlocked){
                         [self gotoUpgradeToLifetimeMemberCore:op_data fee_item:fee_price_item account:account_info];
                     }
                 }];
             }
         }];
        return nil;
    })] catch:(^id(id error) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

@end
