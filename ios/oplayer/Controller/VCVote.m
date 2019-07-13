//
//  VCVote.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCVote.h"
#import "BitsharesClientManager.h"
#import "ViewCommitteeVoteCell.h"
#import "ViewWorkerVoteCell.h"

#import "MBProgressHUDSingleton.h"
#import "OrgUtils.h"

#import "VCCommonLogic.h"

#import "VCSearchNetwork.h"
#import "VCBtsaiWebView.h"

enum
{
    kBottomButtonTagSubmitVote = 0, //  提交投票
    kBottomButtonTagProxy,          //  设置代理/取消代理
};

/**
 *  表格分组类型以及各种TAG
 */
enum
{
    kSecTypeCommitteeActive = 0,    //  活跃理事会成员
    kSecTypeCommitteeCandidate,     //  候选理事会成员（非活跃）
    kSecTypeWitnessActive,          //  活跃见证人
    kSecTypeWitnessCandidate,       //  候选见证人（非活跃）
    kSecTypeWorkerExpired,          //  过期的预算项目
    kSecTypeWorkerNotExpired,       //  非过期的预算项目
    kSecTypeWorkerActive,           //  活跃预算项目（能拿到预算金额的）
    kSecTypeWorkerInactive,         //  提案预算项目（投票尚未通过的预算项目）
    
    kBtnTagProxyHelp = 100,         //  帮助：当前代理人
};

@interface VCVote ()
{
    NSString*       _const_proxy_to_self;   //  投票给自身的特殊ID号
    BOOL            _bHaveProxy;            //  是否有投票代理。
    UIView*         _pBottomView;           //  底部按钮容器
    NSDictionary*   _currVoteInfos;         //  当前投票信息
}

@end

@implementation VCVote

-(void)dealloc
{
    _pBottomView = nil;
    _currVoteInfos = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        //  断言：确保已经登录。
        assert([[WalletManager sharedWalletManager] isWalletExist]);
        //  初始化自身代理ID号
        _const_proxy_to_self = [[[ChainObjectManager sharedChainObjectManager] getDefaultParameters] objectForKey:@"voting_proxy_to_self"];
        //  进入界面先判断一次（请求数据完毕后会再次更新）
        id full_account_data = [[WalletManager sharedWalletManager] getWalletAccountInfo];
        id account_data = [full_account_data objectForKey:@"account"];
        id account_options = [account_data objectForKey:@"options"];
        assert(account_options);
        _bHaveProxy = ![[account_options objectForKey:@"voting_account"] isEqualToString:_const_proxy_to_self];
        _currVoteInfos = nil;
    }
    return self;
}

- (NSArray*)getTitleStringArray
{
    return @[NSLocalizedString(@"kLabelVotingCommittees", @"理事会"),
             NSLocalizedString(@"kLabelVotingWitnesses", @"见证人"),
             NSLocalizedString(@"kLabelVotingWorkers", @"预算项目")];
}

- (NSArray*)getSubPageVCArray
{
    id vc1 = [[VCVotePage alloc] initWithOwner:self vote_type:evt_committee];
    id vc2 = [[VCVotePage alloc] initWithOwner:self vote_type:evt_witness];
    id vc3 = [[VCVotePage alloc] initWithOwner:self vote_type:evt_work];
    return @[vc1, vc2, vc3];
}

#pragma mark- for actions

/**
 *  (private) 获取完整的帐号信息。
 */
- (id)_get_full_account_data
{
    id wallet_account_info = [[WalletManager sharedWalletManager] getWalletAccountInfo];
    assert(wallet_account_info);
    id account_id = [wallet_account_info objectForKey:@"account"][@"id"];
    id full_account_data = [[ChainObjectManager sharedChainObjectManager] getFullAccountDataFromCache:account_id];
    if (!full_account_data){
        full_account_data = wallet_account_info;
    }
    return full_account_data;
}

/**
 *  (private) 获取手续费对象。
 */
- (NSDictionary*)_get_fee_item:(id)full_account_data
{
    return [[ChainObjectManager sharedChainObjectManager] getFeeItem:ebo_account_update full_account_data:full_account_data];
}

/**
 *  (private) 投票成功之后刷新UI
 */
- (void)_refresh_ui:(id)voting_info
{
    [self _updateBottomButtonTitle:voting_info];
    if (_subvcArrays){
        for (VCVotePage* vc in _subvcArrays) {
            [vc onQueryVotingInfoResponsed:voting_info];
        }
    }
}

/**
 *  (private) 执行投票请求核心
 */
- (void)_processActionCore:(id)fee_item
         full_account_data:(id)full_account_data
        new_voting_account:(id)new_voting_account
                 new_votes:(NSArray*)new_votes
                     title:(id)title
{
    assert(fee_item);
    assert(full_account_data);
    assert(new_voting_account);
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            [self _processActionUnlockCore:fee_item
                         full_account_data:full_account_data
                        new_voting_account:new_voting_account
                                 new_votes:new_votes title:title];
        }
    }];
}

/**
 *  (private) 排序投票信息（这个排序方式不能调整，和官方网页版一致。）
 */
- (NSArray*)_sort_votes:(NSArray*)votes
{
    //  投票格式 投票类型:投票ID
    //  这里根据投票ID升序排列
    return [votes sortedArrayUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        id ary1 = [obj1 componentsSeparatedByString:@":"];
        id ary2 = [obj2 componentsSeparatedByString:@":"];
        NSInteger vote_id_1 = [[ary1 lastObject] integerValue];
        NSInteger vote_id_2 = [[ary2 lastObject] integerValue];
        if (vote_id_1 < vote_id_2){
            return NSOrderedAscending;
        }else if (vote_id_1 > vote_id_2){
            return NSOrderedDescending;
        }else{
            return NSOrderedSame;
        }
    })];
}

- (void)_processActionUnlockCore:(id)fee_item
               full_account_data:(id)full_account_data
              new_voting_account:(id)new_voting_account
                       new_votes:(NSArray*)new_votes
                           title:(id)title
{
    assert(fee_item);
    assert(full_account_data);
    assert(new_voting_account);
    
    //  默认为空
    if (!new_votes){
        new_votes = @[];
    }else{
        new_votes = [self _sort_votes:new_votes];
    }
    
    //  统计数量（TODO:fowallet 这2个数据实际没什么用？）
    NSInteger num_witness = 0;
    NSInteger num_committee = 0;
    for (id vote_id in new_votes) {
        id ary = [vote_id componentsSeparatedByString:@":"];
        NSInteger vote_type = [ary[0] integerValue];
        switch (vote_type) {
            case ebvt_committee:
                num_committee++;
                break;
            case ebvt_witness:
                num_witness++;
                break;
            default:
                break;
        }
    }
    
    //  构造请求数据
    id fee_asset_id = [fee_item objectForKey:@"fee_asset_id"];
    id account_data = [full_account_data objectForKey:@"account"];
    id account_id = [account_data objectForKey:@"id"];
    id op_data = @{
                   @"fee":@{@"amount":@0, @"asset_id":fee_asset_id},
                   @"account":account_id,
                   @"new_options":@{
                           @"memo_key":account_data[@"options"][@"memo_key"],
                           @"voting_account":new_voting_account,
                           @"num_witness":@(num_witness),
                           @"num_committee":@(num_committee),
                           @"votes":new_votes
                           },
                   };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_account_update
                     using_owner_authority:NO
                  invoke_proposal_callback:NO
                                    opdata:op_data
                                 opaccount:account_data
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
         assert(!isProposal);
         //  请求网络广播
         [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
         [[[[BitsharesClientManager sharedBitsharesClientManager] accountUpdate:op_data] then:(^id(id data) {
             //  投票成功、继续请求、刷新界面。
             [[[[ChainObjectManager sharedChainObjectManager] queryAccountVotingInfos:account_id] then:(^id(id vote_info) {
                 [self hideBlockView];
                 [self _refresh_ui:vote_info];
                 [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcVoteTipTxFullOK", @"%@成功。"), title]];
                 //  [统计]
                 [OrgUtils logEvents:@"txVotingFullOK" params:@{@"account":account_id}];
                 return nil;
             })] catch:(^id(id error) {
                 [self hideBlockView];
                 [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcVoteTipTxOK", @"%@成功，但刷新界面失败，请稍后再试。"), title]];
                 //  [统计]
                 [OrgUtils logEvents:@"txVotingOK" params:@{@"account":account_id}];
                 return nil;
             })];
             return nil;
         })] catch:(^id(id error) {
             [self hideBlockView];
             [OrgUtils showGrapheneError:error];
             //  [统计]
             [OrgUtils logEvents:@"txVotingFailed" params:@{@"account":account_id}];
             return nil;
         })];
     }];
}

/**
 *  (private) 交易行为：设置代理人
 */
- (void)_processActionSettingProxy
{
    //  1、判断手续费是否足够
    id full_account_data = [self _get_full_account_data];
    id fee_item = [self _get_fee_item:full_account_data];
    if (![[fee_item objectForKey:@"sufficient"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
        return;
    }
    
    //  2、选择委托投票人
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAccount callback:^(id account_info) {
        if (account_info){
            [self _processActionCore:fee_item
                   full_account_data:full_account_data
                  new_voting_account:[account_info objectForKey:@"id"]
                           new_votes:nil
                               title:NSLocalizedString(@"kVcVotePrefixSetupProxy", @"设置代理")];
        }
    }];
    vc.title = NSLocalizedString(@"kVcTitleSelectProxy", @"选择代理帐号");
    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

/**
 *  (private) 交易行为：删除代理人
 */
- (void)_processActionRemoveProxy
{
    //  1、判断手续费是否足够
    id full_account_data = [self _get_full_account_data];
    id fee_item = [self _get_fee_item:full_account_data];
    if (![[fee_item objectForKey:@"sufficient"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
        return;
    }
    
    //  2、执行请求（设置为自己投票）
    [self _processActionCore:fee_item
           full_account_data:full_account_data
          new_voting_account:_const_proxy_to_self
                   new_votes:nil
                       title:NSLocalizedString(@"kVcVotePrefixRemoveProxy", @"删除代理")];
}

/**
 *  (private) 交易行为：修改投票（如果有代理人则会自动删除。）
 */
- (void)_processActionVoting
{
    //  1、检查投票信息是否发生变化（有代理则不检测，有代理则取消代理，保持投票信息不变即可。）
    id new_votes = [self _getAllSelectedVotingInfos];
    if (!_bHaveProxy){
        id old_votes = [[_currVoteInfos objectForKey:@"voting_hash"] allKeys];
        if (![self _isVotingChanged:old_votes new_votes:new_votes]){
            [OrgUtils makeToast:NSLocalizedString(@"kVcVoteTipVoteNoChange", @"投票信息没有变化，不用提交。")];
            return;
        }
    }
    
    //  2、检查手续费是否足够
    id full_account_data = [self _get_full_account_data];
    id fee_item = [self _get_fee_item:full_account_data];
    if (![[fee_item objectForKey:@"sufficient"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
        return;
    }
    
    //  3、执行请求（代理设置为自己投票）
    [self _processActionCore:fee_item
           full_account_data:full_account_data
          new_voting_account:_const_proxy_to_self
                   new_votes:new_votes
                       title:NSLocalizedString(@"kVcVotePrefixVoting", @"投票")];
}

/**
 *  (private) 辅助 - 判断投票信息是否发生变化。
 */
- (BOOL)_isVotingChanged:(NSArray*)old_votes new_votes:(NSArray*)new_votes
{
    assert(old_votes);
    assert(new_votes);
    
    if ([old_votes count] != [new_votes count]){
        return YES;
    }
    
    //  排序投票信息
    old_votes = [old_votes sortedArrayUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    })];
    
    new_votes = [new_votes sortedArrayUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    })];
    
    //  逐个比较
    NSInteger idx = 0;
    for (id vote_id_old in old_votes) {
        id vote_id_new = [new_votes objectAtIndex:idx];
        if (![vote_id_old isEqualToString:vote_id_new]){
            return YES;
        }
        ++idx;
    }
    
    //  没变化
    return NO;
}

/**
 *  (private) 事件 - 投票界面底部按钮点击
 */
- (void)onButtomButtonClicked:(UIButton*)sender
{
    if (!_currVoteInfos){
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return;
    }
    
    //  TODO:fowallet 没有直接 更换代理 的操作。
    switch (sender.tag) {
        case kBottomButtonTagSubmitVote:
        {
            //  设置了代理人的情况，先弹框告知用户。
            if (_bHaveProxy){
                [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kVcVoteTipAutoCancelProxy", @"您设置了投票代理人，手动编辑投票信息将会取消代理人，继续投票吗？")
                                                                       withTitle:nil
                                                                      completion:^(NSInteger buttonIndex)
                 {
                     if (buttonIndex == 1)
                     {
                         [self _processActionVoting];   //  取消代理人并修改投票。
                     }
                 }];
            }else{
                [self _processActionVoting];            //  没代理人，则直接修改投票。
            }
        }
            break;
        case kBottomButtonTagProxy:
        {
            if (_bHaveProxy){
                [self _processActionRemoveProxy];       //  删除代理
            }else{
                [self _processActionSettingProxy];      //  设置代理
            }
        }
            break;
        default:
            assert(false);
            break;
    }
}

/**
 *  (private) 重置用户所做的修改
 */
- (void)onResetModifyCLicked
{
    for (VCVotePage* vc in _subvcArrays) {
        [vc resetUserModify];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    [self showRightButton:NSLocalizedString(@"kVcVoteBtnReset", @"重置") action:@selector(onResetModifyCLicked)];
    
    //  底部按钮尺寸
    CGFloat safeHeight = [self heightForBottomSafeArea];
    CGFloat fBottomViewHeight = 60.0f;
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat tableViewHeight = screenRect.size.height - [self heightForStatusAndNaviBar] - fBottomViewHeight - safeHeight;
    
    //  UI - 顶部按钮：买入、卖出、收藏
    _pBottomView = [[UIView alloc] initWithFrame:CGRectMake(0, tableViewHeight, screenRect.size.width, fBottomViewHeight + safeHeight)];
    [self.view addSubview:_pBottomView];
    _pBottomView.backgroundColor = [ThemeManager sharedThemeManager].tabBarColor;
    CGFloat fBottomBuySellWidth = screenRect.size.width;
    CGFloat fBottomButtonWidth = (fBottomBuySellWidth - 36) / 2;
    CGFloat fBottomButton = 38.0f;
    UIButton* btnBottomBuy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnBottomBuy.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    btnBottomBuy.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [btnBottomBuy setTitle:NSLocalizedString(@"kVcVoteBtnSubmitProxy", @"提交投票") forState:UIControlStateNormal];
    [btnBottomBuy setTitleColor:[ThemeManager sharedThemeManager].textColorPercent forState:UIControlStateNormal];
    btnBottomBuy.userInteractionEnabled = YES;
    [btnBottomBuy addTarget:self action:@selector(onButtomButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnBottomBuy.frame = CGRectMake(12, (fBottomViewHeight  - fBottomButton) / 2, fBottomButtonWidth, fBottomButton);
    btnBottomBuy.tag = kBottomButtonTagSubmitVote;
    btnBottomBuy.backgroundColor = [ThemeManager sharedThemeManager].buyColor;
    [_pBottomView addSubview:btnBottomBuy];
    UIButton* btnBottomSell = [UIButton buttonWithType:UIButtonTypeSystem];
    btnBottomSell.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    btnBottomSell.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    if (_bHaveProxy){
        [btnBottomSell setTitle:NSLocalizedString(@"kVcVoteBtnCancelProxy", @"取消代理") forState:UIControlStateNormal];
    }else{
        [btnBottomSell setTitle:NSLocalizedString(@"kVcVoteBtnSetupProxy", @"设置代理") forState:UIControlStateNormal];
    }
    [btnBottomSell setTitleColor:[ThemeManager sharedThemeManager].textColorPercent forState:UIControlStateNormal];
    btnBottomSell.userInteractionEnabled = YES;
    [btnBottomSell addTarget:self action:@selector(onButtomButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnBottomSell.frame = CGRectMake(12 + fBottomButtonWidth + 12, (fBottomViewHeight  - fBottomButton) / 2, fBottomButtonWidth, fBottomButton);
    btnBottomSell.tag = kBottomButtonTagProxy;
    btnBottomSell.backgroundColor = [ThemeManager sharedThemeManager].sellColor;
    [_pBottomView addSubview:btnBottomSell];
    
    //  查询：全局信息（活跃见证人等）、理事会信息、见证人信息、预算项目信息、预算对象信息、投票信息。
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    WsPromise* p0 = [api exec:@"get_global_properties" params:@[]];
    WsPromise* p1 = [[api exec:@"get_committee_count" params:@[]] then:(^id(id data) {
        NSMutableArray* ary = [NSMutableArray array];
        for (int i = 1; i <= [data intValue]; ++i) {
            [ary addObject:[NSString stringWithFormat:@"1.%@.%@", @(ebot_committee_member), @(i)]];
        }
        return [api exec:@"get_committee_members" params:@[ary]];
    })];
    WsPromise* p2 = [[api exec:@"get_witness_count" params:@[]] then:(^id(id data) {
        NSMutableArray* ary = [NSMutableArray array];
        for (int i = 1; i <= [data intValue]; ++i) {
            [ary addObject:[NSString stringWithFormat:@"1.%@.%@", @(ebot_witness), @(i)]];
        }
        return [api exec:@"get_witnesses" params:@[ary]];
    })];
    WsPromise* p3 = [api exec:@"get_all_workers" params:@[]];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    WsPromise* p4 = [chainMgr queryLastBudgetObject];
    WsPromise* p5 = [chainMgr queryAccountVotingInfos:[[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"][@"id"]];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[WsPromise all:@[p0, p1, p2, p3, p4, p5]] then:(^id(id data_array) {
        [chainMgr updateObjectGlobalProperties:[data_array objectAtIndex:0]];
        NSMutableDictionary* uid_hash = [NSMutableDictionary dictionary];
        id ary_committee = data_array[1];
        id ary_witness = data_array[2];
        id ary_work = data_array[3];
        //  预算项目
        id last_budget_object = data_array[4];
        if (last_budget_object && [last_budget_object isKindOfClass:[NSNull class]]){
            last_budget_object = nil;
        }
        id voting_info = data_array[5];
        //  当前角色 vote_info 查询完毕之后刷新按钮信息。
        [self _updateBottomButtonTitle:voting_info];
        for (id info in ary_committee) {
            if (!info || [info isKindOfClass:[NSNull class]]){
                continue;
            }
            uid_hash[info[@"committee_member_account"]] = @YES;
        }
        for (id info in ary_witness) {
            if (!info || [info isKindOfClass:[NSNull class]]){
                continue;
            }
            uid_hash[info[@"witness_account"]] = @YES;
        }
        for (id info in ary_work) {
            if (!info || [info isKindOfClass:[NSNull class]]){
                continue;
            }
            uid_hash[info[@"worker_account"]] = @YES;
        }
        return [[chainMgr queryAllAccountsInfo:[uid_hash allKeys]] then:(^id(id data) {
            [self hideBlockView];
            NSInteger idx = 1;
            for (VCVotePage* vc in _subvcArrays) {
                [vc onQueryDataResponsed:data_array[idx] last_budget_object:last_budget_object voting_info:voting_info];
                ++idx;
            }
            return @YES;
        })];
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)_updateBottomButtonTitle:(NSDictionary*)vote_info
{
    assert(_pBottomView);
    assert(vote_info);
    _currVoteInfos = vote_info;
    //  更新是否有代理人标记
    _bHaveProxy = [[vote_info objectForKey:@"have_proxy"] boolValue];
    for (UIView* subview in _pBottomView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]){
            if (subview.tag == kBottomButtonTagProxy){
                UIButton* btn = (UIButton*)subview;
                if (_bHaveProxy){
                    [btn setTitle:NSLocalizedString(@"kVcVoteBtnCancelProxy", @"取消代理") forState:UIControlStateNormal];
                }else{
                    [btn setTitle:NSLocalizedString(@"kVcVoteBtnSetupProxy", @"设置代理") forState:UIControlStateNormal];
                }
                break;
            }
        }
    }
}

/**
 *  (private) 获取用户选择的投票项目
 */
- (NSArray*)_getAllSelectedVotingInfos
{
    NSMutableArray* vote_ids = [NSMutableArray array];
    for (VCVotePage* vc in _subvcArrays) {
        [vote_ids addObjectsFromArray:[vc getCurrSelectVotingInfos]];
    }
    return [vote_ids copy];
}

@end

@interface VCVotePage ()
{
    __weak VCBase*      _owner;             //  REMARK：声明为 weak，否则会导致循环引用。
    NSDictionary*       _votingInfo;
    EVoteType           _vote_type;
    BOOL                _have_proxy;
    NSInteger           _bts_precision;
    double              _bts_precision_pow;
    
    NSDecimalNumber*    _nTotalBudget;      //  预算总额（仅worker项目可能存在，worker也可能为nil。）
    NSString*           _nActiveMinVoteNum; //  预算项目通过最低票数（仅worker项目可能存在，worker也可能为nil。）
    
    UILabel*            _lbProxyAccount;
    UIButton*           _btnProxyHelp;
    UIView*             _viewProxySepLine;  //  代理人分隔线
    UITableViewBase*    _mainTableView;
    NSMutableArray*     _sectionDataArray;
    
    BOOL                _bDirty;            //  用户是否进行编辑了（编辑了则为YES，否则为NO。）
}

@end

@implementation VCVotePage

-(void)dealloc
{
    _lbProxyAccount = nil;
    _btnProxyHelp = nil;
    _viewProxySepLine = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _owner = nil;
    _nTotalBudget = nil;
    _nActiveMinVoteNum = nil;
}

- (id)initWithOwner:(VCBase*)owner vote_type:(EVoteType)vote_type
{
    self = [super init];
    if (self) {
        // Custom initialization
        _owner = owner;
        _votingInfo = nil;
        _vote_type = vote_type;
        _have_proxy = NO;
        _sectionDataArray = [NSMutableArray array];
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        id bts_asset = [chainMgr getChainObjectByID:chainMgr.grapheneCoreAssetID];
        assert(bts_asset);
        _bts_precision = [[bts_asset objectForKey:@"precision"] integerValue];
        _bts_precision_pow = pow(10, _bts_precision);
        _nTotalBudget = nil;
        _nActiveMinVoteNum = nil;
        _bDirty = NO;
    }
    return self;
}

/**
 *  调整主列表尺寸，便于在顶部显示代理人信息。
 */
- (void)_adjustTableViewForProxyAccountHeader
{
    assert(_votingInfo);
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat fProxyHeight = _have_proxy ? 44 : 0;
    if (_have_proxy){
        //  有代理人的情况
        if (!_lbProxyAccount){
            _lbProxyAccount = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, screenRect.size.width, fProxyHeight)];
            _lbProxyAccount.lineBreakMode = NSLineBreakByTruncatingTail;
            _lbProxyAccount.textAlignment = NSTextAlignmentCenter;
            _lbProxyAccount.numberOfLines = 1;
            _lbProxyAccount.backgroundColor = [UIColor clearColor];
            _lbProxyAccount.font = [UIFont boldSystemFontOfSize:16];
            _lbProxyAccount.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
            _lbProxyAccount.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcVoteTipCurrentProxy", @"当前代理"), [[_votingInfo objectForKey:@"voting_account"] objectForKey:@"name"]];
            [self.view addSubview:_lbProxyAccount];
            _lbProxyAccount.adjustsFontSizeToFitWidth = YES;
            
            //  UI - 帮助按钮
            _btnProxyHelp = [self _genHelpButton:kBtnTagProxyHelp];
            [self.view addSubview:_btnProxyHelp];
            
            //  UI - 分隔线
            CGFloat fSepLineHeight = 0.5f;
            _viewProxySepLine = [[UIView alloc] initWithFrame:CGRectMake(0, fProxyHeight-fSepLineHeight, screenRect.size.width, fSepLineHeight)];
            _viewProxySepLine.backgroundColor = [ThemeManager sharedThemeManager].textColorGray;
            [self.view addSubview:_viewProxySepLine];
        }
    }else{
        //  无代理人的情况
        if (_lbProxyAccount){
            [_lbProxyAccount removeFromSuperview];
            _lbProxyAccount = nil;
        }
        if (_btnProxyHelp){
            [_btnProxyHelp removeFromSuperview];
            _btnProxyHelp = nil;
        }
        if (_viewProxySepLine){
            [_viewProxySepLine removeFromSuperview];
            _viewProxySepLine = nil;
        }
    }
    
    //  更新主列表 frame
    CGFloat fBottomViewHeight = 60.0f + fProxyHeight;
    CGRect rect = CGRectMake(0, fProxyHeight, screenRect.size.width,
                             screenRect.size.height - fBottomViewHeight - [self heightForStatusAndNaviBar] - 32 - [self heightForBottomSafeArea]);
    _mainTableView.frame = rect;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    // Do any additional setup after loading the view.
    
    //  UI - 代理人标签初始化为 nil。
    _lbProxyAccount = nil;
    _viewProxySepLine = nil;
    
    //  UI - 主列表
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat fBottomViewHeight = 60.0f;
    CGRect rect = CGRectMake(0, 0, screenRect.size.width,
                             screenRect.size.height - fBottomViewHeight - [self heightForStatusAndNaviBar] - 32 - [self heightForBottomSafeArea]);
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    //  可编辑模式
    _mainTableView.editing = YES;
    [self.view addSubview:_mainTableView];
}

/**
 *  (private) 按照指定键值降序排列数组。
 */
- (NSArray*)sort_descending_data_by:(NSString*)key data_array:(NSArray*)data_array
{
    return [data_array sortedArrayUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        unsigned long long v1 = [[obj1 objectForKey:key] unsignedLongLongValue];
        unsigned long long v2 = [[obj2 objectForKey:key] unsignedLongLongValue];
        if (v1 > v2){
            return NSOrderedAscending;
        }else{
            return NSOrderedDescending;
        }
    })];
}

/**
 *  (public) 获取当前用户选择的投票列表。
 */
- (NSArray*)getCurrSelectVotingInfos
{
    assert(_mainTableView);
    assert(_sectionDataArray);
    
    NSMutableArray* selected_vote_id = [NSMutableArray array];
    
    for (id section_data in _sectionDataArray) {
        for (id row_data in [section_data objectForKey:@"kDataArray"]) {
            if ([[row_data objectForKey:@"_kSelected"] boolValue]){
                //  理事会、见证人
                if (_vote_type == evt_work){
                    //  TODO:fowallet vote_against 反对票（暂时没用到）
                    [selected_vote_id addObject:[row_data objectForKey:@"vote_for"]];
                }else{
                    [selected_vote_id addObject:[row_data objectForKey:@"vote_id"]];
                }
            }
        }
    }
    
    return [selected_vote_id copy];
}

/**
 *  (public) 重置用户所做的修改。
 */
- (void)resetUserModify
{
    assert(_sectionDataArray);
    
    _bDirty = NO;
    for (id section_data in _sectionDataArray) {
        for (id row_data in [section_data objectForKey:@"kDataArray"]) {
            row_data[@"_kSelected"] = @([[row_data objectForKey:@"_kOldSelected"] boolValue]);
        }
    }
    
    //  刷新
    [_mainTableView reloadData];
}

/**
 *  (public) 处理数据响应
 *  last_budget_object -    预算项目对象（可能为nil）
 */
- (void)onQueryDataResponsed:(id)data_array last_budget_object:(id)last_budget_object voting_info:(id)voting_info
{
    //  保存
    assert(voting_info);
    _votingInfo = voting_info;
    
    //  更新代理人信息
    _have_proxy = [[_votingInfo objectForKey:@"have_proxy"] boolValue];
    if (_have_proxy){
        [self _adjustTableViewForProxyAccountHeader];
    }
    
    //  筛选不为nil的数据
    data_array = [data_array ruby_select:(^BOOL(id src) {
        return src && ![src isKindOfClass:[NSNull class]];
    })];
    
    id gp = [[ChainObjectManager sharedChainObjectManager] getObjectGlobalProperties];
    assert(gp);
    id active_committee_members = gp[@"active_committee_members"];
    id active_witnesses = gp[@"active_witnesses"];
    NSMutableDictionary* active_committee_members_hash = [NSMutableDictionary dictionary];
    NSMutableDictionary* active_witnesses_hash = [NSMutableDictionary dictionary];
    for (id oid in active_committee_members) {
        active_committee_members_hash[oid] = @YES;
    }
    for (id oid in active_witnesses) {
        active_witnesses_hash[oid] = @YES;
    }
    
    id voting_hash = [_votingInfo objectForKey:@"voting_hash"];
    if (_vote_type == evt_work){
        //  预算提案（活跃预算、提案预算、过期预算）

        //  1、筛选过期和有效的预算项目
        NSMutableArray* ary_expired_worker = [NSMutableArray array];
        NSMutableArray* ary_valid = [NSMutableArray array];
        NSTimeInterval now_ts = [[NSDate date] timeIntervalSince1970];
        for (id worker in data_array) {
            id m_worker = [worker mutableCopy];
            BOOL selected = [[voting_hash objectForKey:m_worker[@"vote_for"]] boolValue];
            m_worker[@"_kSelected"] = @(selected);
            m_worker[@"_kOldSelected"] = @(selected);
            NSTimeInterval end_date_ts = [OrgUtils parseBitsharesTimeString:[worker objectForKey:@"work_end_date"]];
            if (now_ts >= end_date_ts){
                [ary_expired_worker addObject:m_worker];
            }else{
                [ary_valid addObject:m_worker];
            }
        }
        //  2、按照得票排序有效预算项目
        id ary_valid_sorted = [self sort_descending_data_by:@"total_votes_for" data_array:ary_valid];
        //  3、有预算项目，则分成活跃和非活跃。无预算项目，则按照投票顺序排序即可。
        if (last_budget_object){
            //  3.1、预算总额 = min(当前预算值 * 24小时, 最大预算)
            id worker_budget = [[last_budget_object objectForKey:@"record"] objectForKey:@"worker_budget"];
            id max_worker_budget = [gp[@"parameters"] objectForKey:@"worker_budget_per_day"];
            id n_max_worker_budget = [NSDecimalNumber decimalNumberWithMantissa:[max_worker_budget unsignedLongLongValue]
                                                                       exponent:-_bts_precision isNegative:NO];
            id n = [NSDecimalNumber decimalNumberWithMantissa:[worker_budget unsignedLongLongValue] exponent:-_bts_precision isNegative:NO];
            _nTotalBudget = [n decimalNumberByMultiplyingBy:[NSDecimalNumber decimalNumberWithString:@"24.0"]];
            //  _nTotalBudget > n_max_worker_budget
            if ([_nTotalBudget compare:n_max_worker_budget] == NSOrderedDescending){
                _nTotalBudget = n_max_worker_budget;
            }
            
            //  3.2 分组（活跃和非活跃）
            NSMutableArray* ary_active = [NSMutableArray array];
            NSMutableArray* ary_inactive = [NSMutableArray array];
            id active_vote_number = nil;
            id zero = [NSDecimalNumber zero];
            id rest_budget = [_nTotalBudget copy];
            for (id worker in ary_valid_sorted) {
                //  rest_budget > 0
                if ([rest_budget compare:zero] == NSOrderedDescending){
                    [ary_active addObject:worker];
                    //  记录活跃最低票数需求。
                    active_vote_number = [worker objectForKey:@"total_votes_for"];
                }else{
                    [ary_inactive addObject:worker];
                }
                //  TODO:fowallet 计算注资比例 = min(rest_budget, daily_pay) / daily_pay
                //  计算下一个 worker 的剩余预算。
                id n_daily_pay = [NSDecimalNumber decimalNumberWithMantissa:[[worker objectForKey:@"daily_pay"] unsignedLongLongValue]
                                                                   exponent:-_bts_precision isNegative:NO];
                rest_budget = [rest_budget decimalNumberBySubtracting:n_daily_pay];
            }
            if (active_vote_number){
                _nActiveMinVoteNum = [OrgUtils formatFloatValue:round([active_vote_number unsignedLongLongValue]/_bts_precision_pow) precision:0];
            }else{
                //  REMARK：没有预算资金，所有投票无论多少都没法通过。
                _nActiveMinVoteNum = @"";
            }
            //  添加组：活跃预算项目和非活跃预算项目
            if ([ary_active count] > 0){
                [_sectionDataArray addObject:@{@"kType":@(kSecTypeWorkerActive), @"kDataArray":ary_active}];
            }
            if ([ary_inactive count] > 0){
                [_sectionDataArray addObject:@{@"kType":@(kSecTypeWorkerInactive), @"kDataArray":ary_inactive}];
            }
        }else{
            _nTotalBudget = nil;
            _nActiveMinVoteNum = nil;
            //  添加组：非过期预算项目
            [_sectionDataArray addObject:@{@"kType":@(kSecTypeWorkerNotExpired), @"kDataArray":ary_valid_sorted}];
        }
        //  添加组：过期预算项目
        [_sectionDataArray addObject:@{@"kType":@(kSecTypeWorkerExpired), @"kDataArray":ary_expired_worker}];
    }else{
        //  理事会、见证人
        NSMutableArray* ary_active = [NSMutableArray array];
        NSMutableArray* ary_candidate = [NSMutableArray array];
        for (id obj in data_array) {
            id oid = obj[@"id"];
            id m_obj = [obj mutableCopy];
            BOOL selected = [[voting_hash objectForKey:m_obj[@"vote_id"]] boolValue];
            m_obj[@"_kSelected"] = @(selected);
            m_obj[@"_kOldSelected"] = @(selected);
            if ([active_committee_members_hash[oid] boolValue] || [active_witnesses_hash[oid] boolValue]){
                [ary_active addObject:m_obj];
            }else{
                [ary_candidate addObject:m_obj];
            }
        }
        
        id sorted_ary_active = [self sort_descending_data_by:@"total_votes" data_array:ary_active];
        id sorted_ary_candidate = [self sort_descending_data_by:@"total_votes" data_array:ary_candidate];
        
        if (_vote_type == evt_committee){
            [_sectionDataArray addObject:@{@"kType":@(kSecTypeCommitteeActive), @"kDataArray":sorted_ary_active}];
            [_sectionDataArray addObject:@{@"kType":@(kSecTypeCommitteeCandidate), @"kDataArray":sorted_ary_candidate}];
        }else{
            [_sectionDataArray addObject:@{@"kType":@(kSecTypeWitnessActive), @"kDataArray":sorted_ary_active}];
            [_sectionDataArray addObject:@{@"kType":@(kSecTypeWitnessCandidate), @"kDataArray":sorted_ary_candidate}];
        }
    }

    //  刷新
    [_mainTableView reloadData];
}

/**
 *  (private) 用户是否编辑过判断
 */
- (BOOL)_isUserModifyed
{
    for (id section_data in _sectionDataArray) {
        for (id row_data in [section_data objectForKey:@"kDataArray"]) {
            BOOL _kSelected = [[row_data objectForKey:@"_kSelected"] boolValue];
            BOOL _kOldSelected = [[row_data objectForKey:@"_kOldSelected"] boolValue];
            if (_kSelected != _kOldSelected){
                return YES;
            }
        }
    }
    return NO;
}

/**
 *  (public) 获取投票信息成功，刷新界面。
 */
- (void)onQueryVotingInfoResponsed:(id)voting_info
{
    //  保存
    assert(voting_info);
    _votingInfo = voting_info;
    
    //  更新代理人信息
    _have_proxy = [[_votingInfo objectForKey:@"have_proxy"] boolValue];
    [self _adjustTableViewForProxyAccountHeader];
    
    //  投票成功（可能更换了代理人，重新初始化脏标记和selected标记。）
    _bDirty = NO;
    id voting_hash = [_votingInfo objectForKey:@"voting_hash"];
    for (id section_data in _sectionDataArray) {
        for (id row_data in [section_data objectForKey:@"kDataArray"]) {
            id vote_id = _vote_type == evt_work ? row_data[@"vote_for"] : row_data[@"vote_id"];
            assert(vote_id);
            BOOL selected = [[voting_hash objectForKey:vote_id] boolValue];
            row_data[@"_kSelected"] = @(selected);
            row_data[@"_kOldSelected"] = @(selected);
        }
    }
    
    //  刷新
    [_mainTableView reloadData];
}

#pragma mark- UITableView edit mode
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleInsert | UITableViewCellEditingStyleDelete;
}

//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
//{
////    tableView selectRowAtIndexPath:<#(nullable NSIndexPath *)#> animated:<#(BOOL)#> scrollPosition:<#(UITableViewScrollPosition)#>
////    [tableView cellForRowAtIndexPath:indexPath].selected = YES;
//    //  TODO:fowallet...
//}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_sectionDataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_sectionDataArray[section][@"kDataArray"] count];
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    //  没有数据的时候则没有 header view
    if ([_sectionDataArray[section][@"kDataArray"] count] <= 0){
        return 0.01f;
    }
    return 44.0f;
}

/**
 *  (private) 帮助按钮点击
 */
- (void)onTipButtonClicked:(UIButton*)sender
{
    NSString* url = nil;
    NSString* title = nil;
    switch (sender.tag) {
        case kSecTypeCommitteeActive:
        {
            //  [统计]
            [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_committee"}];
            url = @"https://btspp.io/qam.html#qa_committee";
            title = NSLocalizedString(@"kVcVoteWhatIsActiveCommittee", @"什么是活跃理事会？");
        }
            break;
        case kSecTypeCommitteeCandidate:
        {
            //  [统计]
            [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_committee_c"}];
            url = @"https://btspp.io/qam.html#qa_committee_c";
            title = NSLocalizedString(@"kVcVoteWhatIsStandbyCommittee", @"什么是候选理事会？");
        }
            break;
        case kSecTypeWitnessActive:
        {
            //  [统计]
            [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_witness"}];
            url = @"https://btspp.io/qam.html#qa_witness";
            title = NSLocalizedString(@"kVcVoteWhatIsActiveWitness", @"什么是活跃见证人？");
        }
            break;
        case kSecTypeWitnessCandidate:
        {
            //  [统计]
            [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_witness_c"}];
            url = @"https://btspp.io/qam.html#qa_witness_c";
            title = NSLocalizedString(@"kVcVoteWhatIsStandbyWitness", @"什么是候选见证人？");
        }
            break;
        case kBtnTagProxyHelp:
        {
            //  [统计]
            [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_proxy"}];
            url = @"https://btspp.io/qam.html#qa_proxy";
            title = NSLocalizedString(@"kVcVoteWhatIsProxy", @"什么是代理人？");
        }
            break;
        default:
            break;
    }
    if (url && title && _owner){
        VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:url];
        vc.title = title;
        [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
    }
}

- (UIButton*)_genHelpButton:(NSInteger)tag
{
    CGFloat xOffset = 12;
    UIButton* btnTips = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];
    CGSize btn_size = btn_image.size;
    [btnTips setBackgroundImage:btn_image forState:UIControlStateNormal];
    btnTips.userInteractionEnabled = YES;
    [btnTips addTarget:self action:@selector(onTipButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnTips.frame = CGRectMake(self.view.bounds.size.width - btn_image.size.width - xOffset, (44 - btn_size.height) / 2, btn_size.width, btn_size.height);
    btnTips.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
    btnTips.tag = tag;
    return btnTips;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if ([_sectionDataArray[section][@"kDataArray"] count] <= 0){
        return [[UIView alloc] init];
    }else{
        CGFloat fWidth = self.view.bounds.size.width;

        UIView* myView = [[UIView alloc] init];
        myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, fWidth - 24, 44)];    //  REMARK：12 和 ViewCallOrderInfoCell 里控件边距一致。
        titleLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:16];

        NSInteger kType = [_sectionDataArray[section][@"kType"] integerValue];
        NSInteger num = [_sectionDataArray[section][@"kDataArray"] count];
        switch (kType) {
            case kSecTypeCommitteeActive:
            {
                titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelVotingActiveCommittees", @"活跃理事会(%@名)"), @(num)];
                [myView addSubview:[self _genHelpButton:kType]];
            }
                break;
            case kSecTypeCommitteeCandidate:
            {
                titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelVotingStandbyCommittees", @"候选理事会(%@名"), @(num)];
                [myView addSubview:[self _genHelpButton:kType]];
            }
                break;
            case kSecTypeWitnessActive:
            {
                titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelVotingActiveWitnesses", @"活跃见证人(%@名"), @(num)];
                [myView addSubview:[self _genHelpButton:kType]];
            }
                break;
            case kSecTypeWitnessCandidate:
            {
                titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelVotingStandbyWitnesses", @"候选见证人(%@名"), @(num)];
                [myView addSubview:[self _genHelpButton:kType]];
            }
                break;
            case kSecTypeWorkerExpired:
                titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelVotingExpiredWP", @"过期预算项目(%@个)"), @(num)];
                break;
            case kSecTypeWorkerNotExpired:
                titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelVotingNotExpiredWP", @"进行中预算项目(%@个)"), @(num)];
                break;
            case kSecTypeWorkerActive:
            {
                titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelVotingActiveWP", @"活跃预算项目(%@个)"), @(num)];
                
                assert(_nTotalBudget);
                UILabel* secLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, fWidth - 24, 44)];
                secLabel.textAlignment = NSTextAlignmentRight;
                secLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
                secLabel.backgroundColor = [UIColor clearColor];
                secLabel.font = [UIFont boldSystemFontOfSize:13];
                secLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kLabelVotingTotalBudget", @"预算总额 ")
                                                                                   value:[NSString stringWithFormat:@"%@", @(round([_nTotalBudget doubleValue]))]
                                                                              titleColor:[ThemeManager sharedThemeManager].textColorNormal
                                                                              valueColor:[ThemeManager sharedThemeManager].textColorMain];
                [myView addSubview:secLabel];
            }
                break;
            case kSecTypeWorkerInactive:
            {
                titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelVotingInactiveWP", @"提案预算项目(%@个)"), @(num)];
                
                assert(_nActiveMinVoteNum);
                UILabel* secLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, fWidth - 24, 44)];
                secLabel.textAlignment = NSTextAlignmentRight;
                secLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
                secLabel.backgroundColor = [UIColor clearColor];
                secLabel.font = [UIFont boldSystemFontOfSize:13];
                
                secLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:NSLocalizedString(@"kLabelVotingWPPassVotes", @"通过所需票数 ")
                                                                                   value:[_nActiveMinVoteNum isEqualToString:@""] ? NSLocalizedString(@"kLabelVotingNoBudget", @"没有预算资金") : _nActiveMinVoteNum
                                                                              titleColor:[ThemeManager sharedThemeManager].textColorNormal
                                                                              valueColor:[ThemeManager sharedThemeManager].textColorMain];
                [myView addSubview:secLabel];
            }
                break;
            default:
                assert(false);
                break;
        }
        [myView addSubview:titleLabel];
        
        return myView;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //  TODO:fowallet
    if (_vote_type == evt_work){
        CGFloat baseHeight = 8.0 + 28.0f * 4;
        return baseHeight;
    }else{
        CGFloat baseHeight = 8.0 + 28.0f * 2;
        return baseHeight;
    }
}

/**
 *  (private) 获取扁平化后的 行号
 */
- (NSInteger)getFlatRow:(NSIndexPath*)indexPath
{
    NSInteger row = 0;
    for (NSInteger sec = 0; sec < indexPath.section; ++sec) {
        row += [_sectionDataArray[sec][@"kDataArray"] count];
    }
    return row + indexPath.row;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_vote_type == evt_work){
        static NSString* identify = @"id_worker_vote";
        ViewWorkerVoteCell* cell = (ViewWorkerVoteCell *)[tableView dequeueReusableCellWithIdentifier:identify];
        if (!cell)
        {
            cell = [[ViewWorkerVoteCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
        }
        cell.showCustomBottomLine = YES;
        cell.bts_precision_pow = _bts_precision_pow;
        [cell setVotingInfo:_votingInfo];
        [cell setTagData:[self getFlatRow:indexPath]];
        id row_data = [_sectionDataArray[indexPath.section][@"kDataArray"] objectAtIndex:indexPath.row];
        [cell setItem: row_data];
        //  默认选中
        if ([[row_data objectForKey:@"_kSelected"] boolValue]){
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
        return cell;
    }else{
        static NSString* identify = @"id_committee_witness_vote";
        ViewCommitteeVoteCell* cell = (ViewCommitteeVoteCell *)[tableView dequeueReusableCellWithIdentifier:identify];
        if (!cell)
        {
            cell = [[ViewCommitteeVoteCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
        }
        cell.showCustomBottomLine = YES;
        cell.voteType = _vote_type;
        cell.bts_precision_pow = _bts_precision_pow;
        cell.dirty = _bDirty;
        [cell setVotingInfo:_votingInfo];
        [cell setTagData:[self getFlatRow:indexPath]];
        id row_data = [_sectionDataArray[indexPath.section][@"kDataArray"] objectAtIndex:indexPath.row];
        [cell setItem: row_data];
        //  默认选中
        if ([[row_data objectForKey:@"_kSelected"] boolValue]){
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
        return cell;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id row_data = [_sectionDataArray[indexPath.section][@"kDataArray"] objectAtIndex:indexPath.row];
    assert(row_data);
    //  更新选中状态
    row_data[@"_kSelected"] = @(YES);
    //  更新脏标记
    _bDirty = [self _isUserModifyed];
    //  TODO:fowallet 新增、删除标记待处理。
//    //  有代理人的情况（需要重新刷新table、所有代投票标签都要移除or添加）
//    if (_have_proxy){
//        //  TODO:fowallet 3个界面都需要更新
//        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
//            [tableView reloadData];
//        }];
//    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(3_0)
{
    id row_data = [_sectionDataArray[indexPath.section][@"kDataArray"] objectAtIndex:indexPath.row];
    assert(row_data);
    //  更新选中状态
    row_data[@"_kSelected"] = @(NO);
    //  更新脏标记
    _bDirty = [self _isUserModifyed];
    //  TODO:fowallet 新增、删除标记待处理。
//    //  有代理人的情况（需要重新刷新table、所有代投票标签都要移除or添加）
//    if (_have_proxy){
//        //  TODO:fowallet 3个界面都需要更新
//        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
//            [tableView reloadData];
//        }];
//    }
}

#pragma mark- for url clicked
- (void)onButtonClicked_Url:(UIButton*)sender
{
    assert(_owner);
    NSInteger tag = sender.tag;
    NSInteger idx = 0;
    id found_row_data = nil;
    for (id section_infos in _sectionDataArray) {
        for (id row_data in section_infos[@"kDataArray"]) {
            if (tag == idx){
                found_row_data = row_data;
                break;
            }
            idx += 1;
        }
        if (found_row_data){
            break;
        }
    }
    assert(found_row_data);
    if (!found_row_data){
        return;
    }
    id url = [found_row_data objectForKey:@"url"];
    if (url && ![url isEqualToString:@""]){
        //  跳转网页（改为系统浏览器打开，不用内置 webview 打开。）
        [OrgUtils safariOpenURL:url];
    }
}

@end

