//
//  VCVestingBalance.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCVestingBalance.h"
#import "VCSearchNetwork.h"
#import "VCImportAccount.h"
#import "BitsharesClientManager.h"
#import "ViewWalletAccountInfoCell.h"
#import "ViewVestingBalanceCell.h"
#import "OrgUtils.h"
#import "ScheduleManager.h"
#import "MyPopviewManager.h"

@interface VCVestingBalance ()
{
    NSDictionary*           _fullAccountInfo;
    BOOL                    _isSelfAccount;
    
    __weak VCBase*          _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCVestingBalance

-(void)dealloc
{
    _owner = nil;
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _fullAccountInfo = nil;
}

- (id)initWithOwner:(VCBase*)owner fullAccountInfo:(NSDictionary*)accountInfo
{
    self = [super init];
    if (self){
        _owner = owner;
        _fullAccountInfo = accountInfo;
        _dataArray = [NSMutableArray array];
        _isSelfAccount = [[WalletManager sharedWalletManager] isMyselfAccount:_fullAccountInfo[@"account"][@"name"]];
    }
    return self;
}

- (void)onQueryVestingBalanceResponsed:(NSArray*)data_array nameHash:(NSDictionary*)nameHash
{
    //  更新数据
    [_dataArray removeAllObjects];
    if (data_array && [data_array count] > 0){
        for (id vesting in data_array) {
            id oid = [vesting objectForKey:@"id"];
            assert(oid);
            if (!oid){
                continue;
            }
            //  略过总金额为 0 的待解冻金额对象。
            if ([[[vesting objectForKey:@"balance"] objectForKey:@"amount"] unsignedLongLongValue] == 0){
                continue;
            }
            //  linear_vesting_policy = 0,
            //  cdd_vesting_policy
            if ([[[vesting objectForKey:@"policy"] objectAtIndex:0] integerValue] == 1){
                id name = [nameHash objectForKey:oid] ?: NSLocalizedString(@"kVestingCellNameCustomVBO", @"自定义解冻金额");
                id m_vesting = [vesting mutableCopy];
                [m_vesting setObject:name forKey:@"kName"];
                [_dataArray addObject:[m_vesting copy]];
            }else{
                //  TODO:fowallet 1.7 暂时不支持 linear_vesting_policy
            }
        }
    }
    
    //  根据ID降序排列
    if ([_dataArray count] > 0){
        [_dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSInteger id1 = [[[[obj1 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            NSInteger id2 = [[[[obj2 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            return id2 - id1;
        })];
    }
    
    //  更新显示
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

- (void)queryVestingBalance
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    id account = [_fullAccountInfo objectForKey:@"account"];
    id uid = [account objectForKey:@"id"];
    assert(uid);
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
    id p1 = [api exec:@"get_vesting_balances" params:@[uid]];
    id p2 = [api exec:@"get_workers_by_account" params:@[uid]];
    id p3 = [api exec:@"get_witness_by_account" params:@[uid]];
    
    [[[WsPromise all:@[p1, p2, p3]] then:(^id(id all_data) {
        NSMutableDictionary* vesting_balance_name_hash = [NSMutableDictionary dictionary];
        id data_array = [all_data objectAtIndex:0];
        id data_workers = [all_data objectAtIndex:1];
        id data_witness = [all_data objectAtIndex:2];
        if (data_workers && [data_workers isKindOfClass:[NSArray class]]){
            for (id worker in data_workers) {
                if ([OrgUtils getWorkerType:worker] == ebwt_vesting){
                    id balance = [[[worker objectForKey:@"worker"] objectAtIndex:1] objectForKey:@"balance"];
                    if (balance){
                        id name = [worker objectForKey:@"name"] ?: NSLocalizedString(@"kVestingCellNameWorkerFunds", @"预算项目薪资");
                        [vesting_balance_name_hash setObject:name forKey:balance];
                    }
                }
            }
        }
        if (data_witness && ![data_witness isKindOfClass:[NSNull class]]){
            id pay_vb = [data_witness objectForKey:@"pay_vb"];
            if (pay_vb){
                [vesting_balance_name_hash setObject:NSLocalizedString(@"kVestingCellNameWitnessFunds", @"见证人薪资") forKey:pay_vb];
            }
        }
        id cashback_vb = [account objectForKey:@"cashback_vb"];
        if (cashback_vb){
            [vesting_balance_name_hash setObject:NSLocalizedString(@"kVestingCellNameCashbackFunds", @"终身会员手续费返现") forKey:cashback_vb];
        }
        NSMutableDictionary* asset_ids = [NSMutableDictionary dictionary];
        for (id vesting in data_array) {
            [asset_ids setObject:@YES forKey:[[vesting objectForKey:@"balance"] objectForKey:@"asset_id"]];
        }
        //  查询 & 缓存
        return [[chainMgr queryAllAssetsInfo:[asset_ids allKeys]] then:(^id(id asset_hash) {
            [_owner hideBlockView];
            [self onQueryVestingBalanceResponsed:data_array nameHash:vesting_balance_name_hash];
            return nil;
        })];
    })] catch:(^id(id error) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kVestingTipsNoData", @"没有任何待解冻金额")];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataArray count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28 + 24 * 2;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_vesting_info_cell";
    ViewVestingBalanceCell* cell = (ViewVestingBalanceCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewVestingBalanceCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:_isSelfAccount ? self : nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.showCustomBottomLine = YES;
    cell.row = indexPath.row;
    [cell setTagData:indexPath.row];
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

/**
 *  (public) 计算已经解冻的余额数量。（可提取的）
 */
+ (unsigned long long)calcVestingBalanceAmount:(id)vesting
{
    id policy = [vesting objectForKey:@"policy"];
    assert(policy);
    //  TODO:fowallet 其他的类型不支持。
    assert([[policy objectAtIndex:0] integerValue] == 1);
    id policy_data = [policy objectAtIndex:1];
    assert(policy_data);
    
    //  vesting seconds     REMARK：解冻周期最低1秒。
    NSUInteger vesting_seconds = MAX([[policy_data objectForKey:@"vesting_seconds"] unsignedIntegerValue], 1L);
    
    //  last update timestamp
    NSTimeInterval coin_seconds_earned_last_update_ts = [OrgUtils parseBitsharesTimeString:policy_data[@"coin_seconds_earned_last_update"]];
    NSTimeInterval now_ts = [[NSDate date] timeIntervalSince1970];
    
    //  my balance & already earned seconds
    unsigned long long total_balance_amount = [[[vesting objectForKey:@"balance"] objectForKey:@"amount"] unsignedLongLongValue];
    unsigned long long coin_seconds_earned = [[policy_data objectForKey:@"coin_seconds_earned"] unsignedLongLongValue];
    
    //  recalc real 'coin_seconds_earned' value
    unsigned long long final_earned = coin_seconds_earned;
    if (now_ts > coin_seconds_earned_last_update_ts){
        unsigned long long delta_seconds = (unsigned long long)(now_ts - coin_seconds_earned_last_update_ts);
        unsigned long long delta_coin_seconds = total_balance_amount * delta_seconds;
        unsigned long long coin_seconds_earned_max = total_balance_amount * vesting_seconds;
        final_earned = MIN(coin_seconds_earned + delta_coin_seconds, coin_seconds_earned_max);
    }
    
    unsigned long long withdraw_max = (unsigned long long)floor(final_earned / (double)vesting_seconds);
    assert(withdraw_max <= total_balance_amount);
    
    return withdraw_max;
}

/**
 *  事件 - 提取待解冻金额
 */
- (void)onButtonClicked_Withdraw:(UIButton*)button
{
    assert(_isSelfAccount);
    
    id vesting = [_dataArray objectAtIndex:button.tag];
    NSLog(@"vesting : %@", vesting[@"id"]);
    
    id policy = [vesting objectForKey:@"policy"];
    assert(policy);
    //  TODO:fowallet 其他的类型不支持。
    assert([[policy objectAtIndex:0] integerValue] == 1);
    id policy_data = [policy objectAtIndex:1];
    id start_claim = [policy_data objectForKey:@"start_claim"];
    NSTimeInterval start_claim_ts = [OrgUtils parseBitsharesTimeString:start_claim];
    NSTimeInterval now_ts = [[NSDate date] timeIntervalSince1970];
    if (now_ts <= start_claim_ts){
        id s = [OrgUtils getDateTimeLocaleString:[NSDate dateWithTimeIntervalSince1970:start_claim_ts]];
        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVestingTipsStartClaim", @"该笔金额在 %@ 之后方可提取。"), s]];
        return;
    }
    
    //  计算可提取数量
    unsigned long long withdraw_available = [[self class] calcVestingBalanceAmount:vesting];
    if (withdraw_available <= 0){
        [OrgUtils makeToast:NSLocalizedString(@"kVestingTipsAvailableZero", @"没有可提取数量，请等待。")];
        return;
    }
    
    //  ----- 准备提取 -----
    
    //  1、判断手续费是否足够。
    id fee_item =  [[ChainObjectManager sharedChainObjectManager] getFeeItem:ebo_vesting_balance_withdraw full_account_data:_fullAccountInfo];
    if (![[fee_item objectForKey:@"sufficient"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
        return;
    }
    
    //  2、解锁钱包or账号
    [_owner GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            [self processWithdrawVestingBalanceCore:vesting
                                  full_account_data:_fullAccountInfo
                                           fee_item:fee_item
                                 withdraw_available:withdraw_available];
        }
    }];
}


- (void)processWithdrawVestingBalanceCore:(id)vesting_balance
                        full_account_data:(id)full_account_data
                                 fee_item:(id)fee_item
                       withdraw_available:(unsigned long long)withdraw_available
{
    assert(vesting_balance);
    assert(full_account_data);
    assert(fee_item);
    id balance_id = vesting_balance[@"id"];
    
    id balance = vesting_balance[@"balance"];
    assert(balance);
    id account = [full_account_data objectForKey:@"account"];
    assert(account);
    
    id uid = [account objectForKey:@"id"];
    
    id op = @{
              @"fee":@{@"amount":@0, @"asset_id":fee_item[@"fee_asset_id"]},
              @"vesting_balance":balance_id,
              @"owner":uid,
              @"amount":@{@"amount":@(withdraw_available), @"asset_id":balance[@"asset_id"]}
              };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [_owner GuardProposalOrNormalTransaction:ebo_vesting_balance_withdraw
                       using_owner_authority:NO invoke_proposal_callback:NO
                                      opdata:op
                                   opaccount:account
                                        body:^(BOOL isProposal, NSDictionary *fee_paying_account)
     {
         assert(!isProposal);
         [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
         [[[[BitsharesClientManager sharedBitsharesClientManager] vestingBalanceWithdraw:op] then:(^id(id data) {
             [_owner hideBlockView];
             [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVestingTipTxVestingBalanceWithdrawFullOK", @"待解冻金额 %@ 提取成功。"), balance_id]];
             //  [统计]
             [Answers logCustomEventWithName:@"txVestingBalanceWithdrawFullOK" customAttributes:@{@"account":uid}];
             //  刷新
             [self queryVestingBalance];
             return nil;
         })] catch:(^id(id error) {
             [_owner hideBlockView];
             [OrgUtils makeToast:NSLocalizedString(@"kTipsTxRequestFailed", @"请求失败，请稍后再试。")];
             //  [统计]
             [Answers logCustomEventWithName:@"txVestingBalanceWithdrawFailed" customAttributes:@{@"account":uid}];
             return nil;
         })];
     }];
}

@end
