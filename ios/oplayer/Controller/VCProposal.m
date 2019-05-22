//
//  VCProposal.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCProposal.h"
#import "VCProposalAuthorizeEdit.h"
#import "BitsharesClientManager.h"
#import "ViewProposalInfoCell.h"
#import "ViewProposalAuthorizedStatusCell.h"
#import "ViewProposalOpInfoCell.h"
#import "ViewProposalOpInfoCell_AccountUpdate.h"
#import "ViewProposalActionsCell.h"
#import "OrgUtils.h"
#import "ScheduleManager.h"
#import "MyPopviewManager.h"

@interface VCProposal ()
{
    UITableViewBase*        _mainTableView;
    UILabel*                _lbEmpty;
    
    NSMutableArray*         _dataArray;
}

@end

@implementation VCProposal

-(void)dealloc
{
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbEmpty = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)queryAllProposals:(NSArray*)account_name_list
{
    if (!account_name_list){
        account_name_list = [[WalletManager sharedWalletManager] getWalletAccountNameList];
    }
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    NSMutableArray* promiseList = [NSMutableArray array];
    for (id accountId in account_name_list) {
        [promiseList addObject:[api exec:@"get_proposed_transactions" params:@[accountId]]];
    }
    
    [[[WsPromise all:promiseList] then:(^id(id data_array) {
        NSMutableArray* proposal_list = [NSMutableArray array];
        NSMutableDictionary* proposal_marked = [NSMutableDictionary dictionary];
        //  查询依赖
        NSMutableDictionary* query_ids = [NSMutableDictionary dictionary];
        NSMutableDictionary* skip_cache_ids = [NSMutableDictionary dictionary];
        for (id proposals in data_array) {
            if ([proposals isKindOfClass:[NSArray class]] && [proposals count] > 0){
                for (id proposal in proposals) {
                    NSString* proposal_id = [proposal objectForKey:@"id"];
                    assert(proposal_id);
                    //  REMARK：已经添加到列表了则略过。部分提案可能在多个账号中存在。所以存在重复的情况。
                    if ([[proposal_marked objectForKey:proposal_id] boolValue]){
                        continue;
                    }
                    //  TODO:fowallet REMARK:需要多种权限的提案暂时不支持。
                    if ([[proposal objectForKey:@"required_active_approvals"] count] + [[proposal objectForKey:@"required_owner_approvals"] count] != 1){
                        continue;
                    }
                    [query_ids setObject:@YES forKey:[proposal objectForKey:@"proposer"]];
                    for (id account_id in [proposal objectForKey:@"available_active_approvals"]) {
                        [query_ids setObject:@YES forKey:account_id];
                        [skip_cache_ids setObject:@YES forKey:account_id];
                    }
                    for (id account_id in [proposal objectForKey:@"available_owner_approvals"]) {
                        [query_ids setObject:@YES forKey:account_id];
                        [skip_cache_ids setObject:@YES forKey:account_id];
                    }
                    for (id account_id in [proposal objectForKey:@"required_active_approvals"]) {
                        [query_ids setObject:@YES forKey:account_id];
                        [skip_cache_ids setObject:@YES forKey:account_id];
                    }
                    for (id account_id in [proposal objectForKey:@"required_owner_approvals"]) {
                        [query_ids setObject:@YES forKey:account_id];
                        [skip_cache_ids setObject:@YES forKey:account_id];
                    }
                    //  TODO:fowallet 进行中 proposed_transaction 中的各种ID
                    
                    id operations = [[proposal objectForKey:@"proposed_transaction"] objectForKey:@"operations"];
                    assert(operations);
                    for (id ary in operations) {
                        assert([ary count] == 2);
                        NSInteger opcode = [[ary firstObject] integerValue];
                        id opdata = [ary lastObject];
                        [OrgUtils extractObjectID:opcode opdata:opdata container:query_ids];
                    }
                    
                    //  添加到列表
                    [proposal_list addObject:proposal];
                    //  标记已存在
                    [proposal_marked setObject:@YES forKey:proposal_id];
                }
            }
        }
        return [[chainMgr queryAllGrapheneObjects:[query_ids allKeys] skipCacheIdHash:skip_cache_ids] then:(^id(id data) {
            //  二次查询依赖
            //  1、查询提案账号权限中的多签成员/代理人等名字信息等。
            NSMutableDictionary* query_account_ids = [NSMutableDictionary dictionary];
            for (id proposal in proposal_list) {
                for (id account_id in [proposal objectForKey:@"required_active_approvals"]) {
                    id account = [chainMgr getChainObjectByID:account_id];
                    assert(account);
                    id account_auths = [[account objectForKey:@"active"] objectForKey:@"account_auths"];
                    assert(account_auths);
                    for (id item in account_auths) {
                        assert([item count] == 2);
                        [query_account_ids setObject:@YES forKey:[item firstObject]];
                    }
                    id voting_account = [[account objectForKey:@"options"] objectForKey:@"voting_account"];
                    if (![voting_account isEqualToString:BTS_GRAPHENE_PROXY_TO_SELF]){
                        [query_account_ids setObject:@YES forKey:voting_account];
                    }
                }
                for (id account_id in [proposal objectForKey:@"required_owner_approvals"]) {
                    id account = [chainMgr getChainObjectByID:account_id];
                    assert(account);
                    id account_auths = [[account objectForKey:@"owner"] objectForKey:@"account_auths"];
                    assert(account_auths);
                    for (id item in account_auths) {
                        assert([item count] == 2);
                        [query_account_ids setObject:@YES forKey:[item firstObject]];
                    }
                    id voting_account = [[account objectForKey:@"options"] objectForKey:@"voting_account"];
                    if (![voting_account isEqualToString:BTS_GRAPHENE_PROXY_TO_SELF]){
                        [query_account_ids setObject:@YES forKey:voting_account];
                    }
                }
            }
            //  2、更新账号信息时候查询投票信息
            //  新vote_id
            NSMutableDictionary* new_vote_id_hash = [NSMutableDictionary dictionary];
            for (id proposal in proposal_list) {
                id operations = [[proposal objectForKey:@"proposed_transaction"] objectForKey:@"operations"];
                assert(operations);
                for (id ary in operations) {
                    assert([ary count] == 2);
                    NSInteger opcode = [[ary firstObject] integerValue];
                    if (opcode == ebo_account_update){
                        id opdata = [ary lastObject];
                        id new_options = [opdata objectForKey:@"new_options"];
                        if (new_options){
                            id votes = [new_options objectForKey:@"votes"];
                            if (votes && [votes count] > 0){
                                for (NSString* vote_id in votes) {
                                    [new_vote_id_hash setObject:@YES forKey:vote_id];
                                }
                            }
                            id voting_account = [new_options objectForKey:@"voting_account"];
                            if (![voting_account isEqualToString:BTS_GRAPHENE_PROXY_TO_SELF]){
                                [query_account_ids setObject:@YES forKey:voting_account];
                            }
                        }
                    }
                }
            }
            //  老vote_id
            for (id account_id in [skip_cache_ids allKeys]) {
                id account = [chainMgr getChainObjectByID:account_id];
                assert(account);
                id options = [account objectForKey:@"options"];
                id votes = [options objectForKey:@"votes"];
                if (votes && [votes count] > 0){
                    for (NSString* vote_id in votes) {
                        [new_vote_id_hash setObject:@YES forKey:vote_id];
                    }
                }
            }
            
            NSArray* vote_id_list = [new_vote_id_hash allKeys];
            
            WsPromise* p1 = [chainMgr queryAllGrapheneObjects:[query_account_ids allKeys]];
            WsPromise* p2 = [chainMgr queryAllVoteIds:vote_id_list];
            
            return [[WsPromise all:@[p1, p2]] then:(^id(id data) {
                //  第三次查询依赖（投票信息中的见证人理事会成员名字等）
                NSMutableDictionary* query_ids_3rd = [NSMutableDictionary dictionary];
                for (id vote_id in vote_id_list) {
                    id vote_info = [chainMgr getVoteInfoByVoteID:vote_id];
                    id committee_member_account = [vote_info objectForKey:@"committee_member_account"];
                    if (committee_member_account){
                        [query_ids_3rd setObject:@YES forKey:committee_member_account];
                    }else{
                        id witness_account = [vote_info objectForKey:@"witness_account"];
                        if (witness_account){
                            [query_ids_3rd setObject:@YES forKey:witness_account];
                        }
                    }
                }
                return [[chainMgr queryAllGrapheneObjects:[query_ids_3rd allKeys]] then:(^id(id data) {
                    [self hideBlockView];
                    [self onqueryAllProposalsResponse:proposal_list];
                    return nil;
                })];
            })];
        })];
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

//  TODO:临时放在这里
//<__NSSingleObjectArrayI 0x600001724040>(
//{
//    "available_active_approvals" =     (
//    );
//    "available_key_approvals" =     (
//    );
//    "available_owner_approvals" =     (
//    );
//    "expiration_time" = "2018-12-09T11:17:53";
//    id = "1.10.16551";
//    "proposed_transaction" =     {
//        expiration = "2018-12-09T11:17:53";
//        extensions =         (
//        );
//        operations =         (
//                              (
//                               0,
//                               {
//                                   amount =                     {
//                                       amount = 3900;
//                                       "asset_id" = "1.3.3581";
//                                   };
//                                   extensions =                     (
//                                   );
//                                   fee =                     {
//                                       amount = 10420;
//                                       "asset_id" = "1.3.0";
//                                   };
//                                   from = "1.2.1035733";
//                                   to = "1.2.543248";
//                               }
//                               )
//                              );
//        "ref_block_num" = 0;
//        "ref_block_prefix" = 0;
//    };
//    proposer = "1.2.1050990";
//    "required_active_approvals" =     (
//                                       "1.2.1035733"
//                                       );
//    "required_owner_approvals" =     (
//    );
//}
//                                        )
- (void)onqueryAllProposalsResponse:(id)proposal_data_array
{
    assert(proposal_data_array);
    
    //  更新列表数据
    [_dataArray removeAllObjects];
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    //  预处理提案原始数据
    for (id proposal in proposal_data_array) {
        //  TODO:fowallet 需要多种权限的提案暂不支持
        assert([[proposal objectForKey:@"required_active_approvals"] count] + [[proposal objectForKey:@"required_owner_approvals"] count] == 1);
        
        //  获取提案执行需要批准的权限数据
        NSDictionary* require_account = nil;
        NSDictionary* permissions = nil;
        BOOL is_active = YES;
        if (!require_account){
            for (id oid in [proposal objectForKey:@"required_active_approvals"]) {
                require_account = [chainMgr getChainObjectByID:oid];
                permissions = [require_account objectForKey:@"active"];
                is_active = YES;
            }
        }
        if (!require_account){
            for (id oid in [proposal objectForKey:@"required_owner_approvals"]) {
                require_account = [chainMgr getChainObjectByID:oid];
                permissions = [require_account objectForKey:@"owner"];
                is_active = NO;
            }
        }
        assert(require_account && permissions);
        
        //  获取多签中每个权限实体详细数据（包括权重等）
        NSMutableDictionary* needAuthorizeHash = [NSMutableDictionary dictionary];
        for (id item in [permissions objectForKey:@"account_auths"]) {
            assert([item count] == 2);
            id account_id = [item firstObject];
            id account = [chainMgr getChainObjectByID:account_id];
            [needAuthorizeHash setObject:@{@"name":account[@"name"], @"key":account_id,
                                           @"threshold":[item lastObject], @"isaccount":@YES, @"isactive":@(is_active)} forKey:account_id];
        }
        for (id item in [permissions objectForKey:@"address_auths"]) {
            assert([item count] == 2);
            id key = [item firstObject];
            [needAuthorizeHash setObject:@{@"name":key, @"key":key, @"threshold":[item lastObject], @"isaddr":@YES, @"isactive":@(is_active)} forKey:key];
        }
        for (id item in [permissions objectForKey:@"key_auths"]) {
            assert([item count] == 2);
            id key = [item firstObject];
            [needAuthorizeHash setObject:@{@"name":key, @"key":key, @"threshold":[item lastObject], @"iskey":@YES, @"isactive":@(is_active)} forKey:key];
        }
        
        //  获取当前授权状态（有哪些实体已授权、哪些未授权）
        NSInteger currThreshold = 0;
        NSInteger passThreshold = [permissions[@"weight_threshold"] integerValue];
        assert(passThreshold > 0);
        NSMutableDictionary* availableHash = [NSMutableDictionary dictionary];
        for (id key in [proposal objectForKey:@"available_active_approvals"]) {
            [availableHash setObject:@{@"isaccount":@YES} forKey:key];
            id item = [needAuthorizeHash objectForKey:key];
            if (item){
                currThreshold += [[item objectForKey:@"threshold"] integerValue];
            }
        }
        for (id key in [proposal objectForKey:@"available_key_approvals"]) {
            [availableHash setObject:@{@"iskey":@YES} forKey:key];
            id item = [needAuthorizeHash objectForKey:key];
            if (item){
                currThreshold += [[item objectForKey:@"threshold"] integerValue];
            }
        }
        for (id key in [proposal objectForKey:@"available_owner_approvals"]) {
            [availableHash setObject:@{@"isaccount":@YES} forKey:key];
            id item = [needAuthorizeHash objectForKey:key];
            if (item){
                currThreshold += [[item objectForKey:@"threshold"] integerValue];
            }
        }
        CGFloat thresholdPercent = currThreshold * 100.0f / (CGFloat)passThreshold;
        if (currThreshold < passThreshold){
            thresholdPercent = fminf(thresholdPercent, 99.0f);
        }
        if (currThreshold > 0){
            thresholdPercent = fmaxf(thresholdPercent, 1.0f);
        }
        
        //  预处理是否进入审核期。
        BOOL inReview = NO;
        id review_period_time = [proposal objectForKey:@"review_period_time"];
        if (review_period_time){
            NSTimeInterval review_period_time_ts = [OrgUtils parseBitsharesTimeString:review_period_time];
            NSTimeInterval now_sec = ceil([[NSDate date] timeIntervalSince1970]);
            if (now_sec >= review_period_time_ts){
                inReview = YES;
            }
        }
        
        //  预处理OP描述信息
        NSMutableArray* new_operations = [NSMutableArray array];
        id operations = [[proposal objectForKey:@"proposed_transaction"] objectForKey:@"operations"];
        for (id ary in operations) {
            assert([ary count] == 2);
            NSInteger opcode = [[ary firstObject] integerValue];
            id opdata = [ary lastObject];
            id new_op = @{
                          @"opcode":@(opcode),
                          @"opdata":opdata,
                          @"uidata":[OrgUtils processOpdata2UiData:opcode opdata:opdata opresult:nil isproposal:YES]
                          };
            [new_operations addObject:new_op];
        }
        
        //  添加到列表
        id mutable_proposal = [proposal mutableCopy];
        id processed_infos = @{
                               @"inReview":@(inReview),                 //  是否进入审核期
                               @"passThreshold":@(passThreshold),       //  通过阈值
                               @"currThreshold":@(currThreshold),       //  当前阈值
                               @"thresholdPercent":@(thresholdPercent), //  当前阈值百分比
                               @"needAuthorizeHash":needAuthorizeHash,
                               @"availableHash":availableHash,
                               @"newOperations":new_operations
                               };
        [mutable_proposal setObject:processed_infos forKey:@"kProcessedData"];
        [_dataArray addObject:[mutable_proposal copy]];
    }
    
    //  根据ID降序排列
    [_dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSInteger id1 = [[[[obj1 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
        NSInteger id2 = [[[[obj2 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
        return id2 - id1;
    })];
    
    //  更新UI显示
    if ([_dataArray count] > 0){
        _mainTableView.hidden = NO;
        [_mainTableView reloadData];
    }else{
        _mainTableView.hidden = YES;
    }
    
    _lbEmpty.hidden = !_mainTableView.hidden;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空数据时的标签
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kProposalTipsNoAnyProposals", @"没有任何提案信息")];
    [self.view addSubview:_lbEmpty];
    
    //  开始查询
    [self queryAllProposals:nil];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    //  proposal base info + authorized view + action buttons + OP-LIST
    return 3 + [[[[_dataArray objectAtIndex:section] objectForKey:@"proposed_transaction"] objectForKey:@"operations"] count];
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    id proposal = [_dataArray objectAtIndex:section];
    
    CGFloat fWidth = self.view.bounds.size.width;
    CGFloat xOffset = tableView.layoutMargins.left;
    
    UIView* myView = [[UIView alloc] init];
    myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 28)];
    titleLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.text = [NSString stringWithFormat:@"%@. #%@", @(section + 1), proposal[@"id"]];
    
    UILabel *dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 28)];
    dateLabel.textColor = [ThemeManager sharedThemeManager].textColorGray;
    dateLabel.textAlignment = NSTextAlignmentRight;
    dateLabel.backgroundColor = [UIColor clearColor];
    dateLabel.font = [UIFont systemFontOfSize:13];
    dateLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcOrderExpired", @"%@过期"),
                      [OrgUtils fmtLimitOrderTimeShowString:[proposal objectForKey:@"expiration_time"]]];
    
    [myView addSubview:titleLabel];
    [myView addSubview:dateLabel];
    
    return myView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 28.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 16.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView* myView = [[UIView alloc] init];
    myView.backgroundColor = [UIColor clearColor];// [ThemeManager sharedThemeManager].appBackColor;
    return myView;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id proposal = [_dataArray objectAtIndex:indexPath.section];
    id newOperations = [[proposal objectForKey:@"kProcessedData"] objectForKey:@"newOperations"];
    assert(newOperations);
    
    if (indexPath.row == 0){
        //  proposal basic infos
        return 4.0 + 28 * 2;
    }else if (indexPath.row == 1){
        //  authorize infos
        id kProcessedData = [proposal objectForKey:@"kProcessedData"];
        assert(kProcessedData);
        id needAuthorizeHash = [kProcessedData objectForKey:@"needAuthorizeHash"];
        return 4.0 + 22 * [needAuthorizeHash count];
    }else if (indexPath.row == 2 + [newOperations count]){
        //  actions buttons
        return tableView.rowHeight;
    }else{
        //  OP LIST
        id operation = [newOperations objectAtIndex:indexPath.row - 2];
        switch ([[operation objectForKey:@"opcode"] integerValue]) {
            case ebo_account_update:
                return [ViewProposalOpInfoCell_AccountUpdate getCellHeight:operation leftOffset:tableView.layoutMargins.left];
            default:
                break;
        }
        return [ViewProposalOpInfoCell getCellHeight:operation leftOffset:tableView.layoutMargins.left];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id proposal = [_dataArray objectAtIndex:indexPath.section];
    id newOperations = [[proposal objectForKey:@"kProcessedData"] objectForKey:@"newOperations"];
    assert(newOperations);
    
    if (indexPath.row == 0){
        //  proposal basic infos: index 0
        static NSString* identify = @"id_proposal_cell";
        ViewProposalInfoCell* cell = (ViewProposalInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
        if (!cell)
        {
            cell = [[ViewProposalInfoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
        }
        cell.showCustomBottomLine = YES;
        [cell setItem:proposal];
        return cell;
    }else if (indexPath.row == 1){
        static NSString* identify = @"id_proposal_authorized_status_cell";
        ViewProposalAuthorizedStatusCell* cell = (ViewProposalAuthorizedStatusCell *)[tableView dequeueReusableCellWithIdentifier:identify];
        if (!cell)
        {
            cell = [[ViewProposalAuthorizedStatusCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
        }
        cell.showCustomBottomLine = YES;
        [cell setItem:proposal];
        return cell;
    }else if (indexPath.row == 2 + [newOperations count]){
        //  action buttons: index is last, ..n]
        static NSString* identify = @"id_proposal_actions_cell";
        ViewProposalActionsCell* cell = (ViewProposalActionsCell *)[tableView dequeueReusableCellWithIdentifier:identify];
        if (!cell)
        {
            cell = [[ViewProposalActionsCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify vc:self];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
        }
        cell.showCustomBottomLine = YES;
        [cell setTagData:indexPath.section];
        [cell setItem:proposal];
        return cell;
    }else{
        //  proposal operations infos: index is [2...n)
        id operation = [newOperations objectAtIndex:indexPath.row - 2];
        switch ([[operation objectForKey:@"opcode"] integerValue]) {
            case ebo_account_update:
            {
                static NSString* identify_account_update = @"id_proposal_op_account_update";
                ViewProposalOpInfoCell_AccountUpdate* cell = [tableView dequeueReusableCellWithIdentifier:identify_account_update];
                if (!cell)
                {
                    cell = [[ViewProposalOpInfoCell_AccountUpdate alloc] initWithStyle:UITableViewCellStyleDefault
                                                                       reuseIdentifier:identify_account_update];
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.backgroundColor = [UIColor clearColor];
                }
//                cell.showCustomBottomLine = YES;
                cell.useBuyColorForTitle = YES;
                [cell setItem:operation];    //  REMARK: skip first row
                return cell;
            }
            default:
            {
                static NSString* identify = @"id_proposal_opinfo_cell";
                ViewProposalOpInfoCell* cell = [tableView dequeueReusableCellWithIdentifier:identify];
                if (!cell)
                {
                    cell = [[ViewProposalOpInfoCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:identify];
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.backgroundColor = [UIColor clearColor];
                }
                cell.showCustomBottomLine = YES;
                cell.useBuyColorForTitle = YES;
                [cell setItem:operation];    //  REMARK: skip first row
                return cell;
            }
        }
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

/**
 *  事件 - 批准提案
 */
- (void)onButtonClicked_Approve:(UIButton*)button
{
    id proposal = [_dataArray objectAtIndex:button.tag];
    assert(proposal);
    
    //  REMARK：查询提案发起者是否处于黑名单中，黑名单中不可批准。
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[chainMgr queryAllGrapheneObjectsSkipCache:@[BTS_GRAPHENE_ACCOUNT_BTSPP_TEAM]] then:(^id(id data) {
        [self hideBlockView];
        id account = [chainMgr getChainObjectByID:BTS_GRAPHENE_ACCOUNT_BTSPP_TEAM];
        id blacklisted_accounts = [account objectForKey:@"blacklisted_accounts"];
        
        id proposer_uid = [proposal objectForKey:@"proposer"];
        id proposer_account = [chainMgr getChainObjectByID:proposer_uid];
        id proposer_registrar = [proposer_account objectForKey:@"registrar"];
        assert(proposer_uid && proposer_account && proposer_registrar);
        
        BOOL in_blacklist = NO;
        if (blacklisted_accounts && [blacklisted_accounts count] > 0){
            for (id uid in blacklisted_accounts) {
                //  发起账号 or 发起账号的注册者 在黑名单种，均存在风险。
                if (uid == proposer_uid || uid == proposer_registrar){
                    in_blacklist = YES;
                    break;
                }
            }
        }
        
        if (in_blacklist){
            [OrgUtils showMessage:[NSString stringWithFormat:NSLocalizedString(@"kProposalSubmitTipsBlockedApprovedForBlackList", @"危险账号 %@，为了您的账号和资金安全，系统已阻止了该操作。"), [proposer_account objectForKey:@"name"]]];
        }else{
            [self _gotoApproveCore:proposal];
        }
        
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)_gotoApproveCore:(id)proposal
{
    //  审核中：仅可移除授权，不可添加授权。
    id kProcessedData = [proposal objectForKey:@"kProcessedData"];
    assert(kProcessedData);
    if ([[kProcessedData objectForKey:@"inReview"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kProposalSubmitTipsInReview", @"提案处于审核中，不能添加授权。")];
        return;
    }
    
    //  解锁钱包
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            [self gotoVcApproveCore:proposal];
        }
    }];
}

/**
 *  转到添加授权界面。
 */
- (void)gotoVcApproveCore:(id)proposal
{
    id kProcessedData = [proposal objectForKey:@"kProcessedData"];
    assert(kProcessedData);
    id needAuthorizeHash = [kProcessedData objectForKey:@"needAuthorizeHash"];
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    NSDictionary* idAccountDataHash = [walletMgr getAllAccountDataHash:NO];
    
    //  1、筛选我钱包中所有的【权限实体】
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    for (id key in needAuthorizeHash) {
        id item = [needAuthorizeHash objectForKey:key];
        assert(item);
        assert([[item objectForKey:@"key"] isEqualToString:key]);
        if ([[item objectForKey:@"isaccount"] boolValue]){
            id account_data = [idAccountDataHash objectForKey:key];
            if (account_data){
                [result setObject:item forKey:key];
            }
        }else if ([[item objectForKey:@"iskey"] boolValue]){
            if ([walletMgr havePrivateKey:key]){
                [result setObject:item forKey:key];
            }
        }else{
            NSLog(@"ignore name:%@ key:%@", item[@"name"], key);
        }
    }
    if ([result count] <= 0){
        [OrgUtils makeToast:NSLocalizedString(@"kProposalSubmitTipsNoPermissionApprove", @"您没有任何权限，没法执行批准操作。")];
        return;
    }
    
    //  2、筛选出尚未批准的【权限实体】
    NSMutableArray* approveArray = [NSMutableArray array];
    id availableHash = [kProcessedData objectForKey:@"availableHash"];
    for (id key in result) {
        id item = [result objectForKey:key];
        assert(item);
        if (![availableHash objectForKey:key]){
            [approveArray addObject:item];
        }
    }
    
    if ([approveArray count] <= 0){
        [OrgUtils makeToast:NSLocalizedString(@"kProposalSubmitTipsYouAlreadyApproved", @"您已经批准，不用重复操作。")];
        return;
    }
    VCProposalAuthorizeEdit* vc = [[VCProposalAuthorizeEdit alloc] initWithProposal:proposal
                                                                           isRemove:NO
                                                                          dataArray:[approveArray copy]
                                                                           callback:^(BOOL isOk, NSDictionary *fee_paying_account, NSDictionary *target_account)
                                   {
                                       if (isOk){
                                           [self onUpdateProposalCore:proposal
                                                     feePayingAccount:fee_paying_account
                                                        targetAccount:target_account
                                                             isRemove:NO];
                                       }else{
                                           NSLog(@"cancel add approve");
                                       }
                                   }];
    vc.title = NSLocalizedString(@"kVcTitleProposalAddApprove", @"批准提案");
    vc.hidesBottomBarWhenPushed = YES;
    [self showModelViewController:vc tag:0];
}

/**
 *  事件 - 否决提案
 */
- (void)onButtonClicked_Reject:(UIButton*)button
{
    id proposal = [_dataArray objectAtIndex:button.tag];
    assert(proposal);
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            [self gotoVcRejectCore:proposal];
        }
    }];
}

/**
 *  转到移除授权界面。
 */
- (void)gotoVcRejectCore:(id)proposal
{
    id kProcessedData = [proposal objectForKey:@"kProcessedData"];
    assert(kProcessedData);
    id availableHash = [kProcessedData objectForKey:@"availableHash"];
    if ([availableHash count] <= 0){
        [OrgUtils makeToast:NSLocalizedString(@"kProposalSubmitTipsNoNeedRemove", @"您尚未添加授权，不用移除。")];
        return;
    }
    id needAuthorizeHash = [kProcessedData objectForKey:@"needAuthorizeHash"];
    NSMutableArray* rejectArray = [NSMutableArray array];
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    NSDictionary* idAccountDataHash = [walletMgr getAllAccountDataHash:NO];
    for (id key in availableHash) {
        //  REMARK：批准之后被刷掉了，无权限了，则不存在于需要授权列表了。
        id item = [needAuthorizeHash objectForKey:key];
        if (item){
            if ([[item objectForKey:@"isaccount"] boolValue]){
                id account_data = [idAccountDataHash objectForKey:key];
                if (account_data){
                    [rejectArray addObject:item];
                }
            }else{
                assert([[item objectForKey:@"iskey"] boolValue]);
                if ([walletMgr havePrivateKey:key]){
                    [rejectArray addObject:item];
                }
            }
        }
    }
    if ([rejectArray count] <= 0){
        [OrgUtils makeToast:NSLocalizedString(@"kProposalSubmitTipsNoNeedRemove", @"您尚未添加授权，不用移除。")];
        return;
    }
    VCProposalAuthorizeEdit* vc = [[VCProposalAuthorizeEdit alloc] initWithProposal:proposal
                                                                           isRemove:YES
                                                                          dataArray:[rejectArray copy]
                                                                           callback:^(BOOL isOk, NSDictionary *fee_paying_account, NSDictionary *target_account)
                                   {
                                       if (isOk){
                                           [self onUpdateProposalCore:proposal
                                                     feePayingAccount:fee_paying_account
                                                        targetAccount:target_account
                                                             isRemove:YES];
                                       }else{
                                           NSLog(@"cancel remove approve");
                                       }
                                   }];
    vc.title = NSLocalizedString(@"kVcTitleProposalRemoveApprove", @"否决提案");
    vc.hidesBottomBarWhenPushed = YES;
    [self showModelViewController:vc tag:0];
}

/**
 *  交易 - 更新提案
 */
- (void)onUpdateProposalCore:(id)proposal feePayingAccount:(id)feePayingAccount targetAccount:(id)targetAccount isRemove:(BOOL)isRemove
{
    assert(proposal);
    assert(feePayingAccount);
    assert(targetAccount);
    
    //    //  1、判断手续费是否足够。（TODO:暂时不判断）
    //    id fee_item =  [[ChainObjectManager sharedChainObjectManager] getFeeItem:ebo_proposal_update full_account_data:feePayingAccount];
    //    if (![[fee_item objectForKey:@"sufficient"] boolValue]){
    //        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
    //        return;
    //    }
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    NSDictionary* permissions = nil;
    NSDictionary* approval_account = nil;
    
    //  添加/移除授权
    NSArray* active_approvals_to_add = nil;
    NSArray* active_approvals_to_remove = nil;
    NSArray* owner_approvals_to_add = nil;
    NSArray* owner_approvals_to_remove = nil;
    NSArray* key_approvals_to_add = nil;
    NSArray* key_approvals_to_remove = nil;
    if (isRemove){
        if ([[targetAccount objectForKey:@"isaccount"] boolValue]){
            approval_account = [chainMgr getChainObjectByID:targetAccount[@"key"]];
            assert(approval_account);
            if ([[targetAccount objectForKey:@"isactive"] boolValue]){
                active_approvals_to_remove = @[targetAccount[@"key"]];
                permissions = [approval_account objectForKey:@"active"];
            }else{
                owner_approvals_to_remove = @[targetAccount[@"key"]];
                permissions = [approval_account objectForKey:@"owner"];
            }
            assert(permissions);
        }else{
            assert([[targetAccount objectForKey:@"iskey"] boolValue]);
            //  REMARK：只有拥有私钥的KEY在可以移除。
            assert([[WalletManager sharedWalletManager] havePrivateKey:targetAccount[@"key"]]);
            key_approvals_to_remove = @[targetAccount[@"key"]];
        }
    }else{
        if ([[targetAccount objectForKey:@"isaccount"] boolValue]){
            approval_account = [chainMgr getChainObjectByID:targetAccount[@"key"]];
            assert(approval_account);
            if ([[targetAccount objectForKey:@"isactive"] boolValue]){
                active_approvals_to_add = @[targetAccount[@"key"]];
                permissions = [approval_account objectForKey:@"active"];
            }else{
                owner_approvals_to_add = @[targetAccount[@"key"]];
                permissions = [approval_account objectForKey:@"owner"];
            }
            assert(permissions);
        }else{
            assert([[targetAccount objectForKey:@"iskey"] boolValue]);
            //  REMARK：只有拥有私钥的KEY在可以添加。
            assert([[WalletManager sharedWalletManager] havePrivateKey:targetAccount[@"key"]]);
            key_approvals_to_add = @[targetAccount[@"key"]];
        }
    }
    
    BOOL needCreateProposal = permissions && ![[WalletManager sharedWalletManager] canAuthorizeThePermission:permissions];
    
    //  REMARK：如果需要创建提案来更新提案，那么把提案内容的手续费支付对象设置为提案权限者对象自身。
    //  否则，会出现手续费对象和权限者对象两个实体，那么新创建的提案存在2个required_active_approvals对象，对大部分客户端不友好。
    NSString* fee_paying_account;
    if (needCreateProposal){
        assert(approval_account);
        fee_paying_account = approval_account[@"id"];
    }else{
        fee_paying_account = feePayingAccount[@"id"];
    }
    
    id opdata = @{
                  @"fee":@{@"amount":@0, @"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID},
                  @"fee_paying_account":fee_paying_account,
                  @"proposal":proposal[@"id"],
                  @"active_approvals_to_add":active_approvals_to_add ?: @[],
                  @"active_approvals_to_remove":active_approvals_to_remove ?: @[],
                  @"owner_approvals_to_add":owner_approvals_to_add ?: @[],
                  @"owner_approvals_to_remove":owner_approvals_to_remove ?: @[],
                  @"key_approvals_to_add":key_approvals_to_add ?: @[],
                  @"key_approvals_to_remove":key_approvals_to_remove ?: @[],
                  };
    
    if (needCreateProposal){
        //  发起提案交易
        assert(approval_account);
        [self askForCreateProposal:ebo_proposal_update
             using_owner_authority:![[targetAccount objectForKey:@"isactive"] boolValue]
          invoke_proposal_callback:NO
                            opdata:opdata
                         opaccount:approval_account
                              body:nil
                  success_callback:^
        {
            //  提案创建成功
            [OrgUtils makeToast:NSLocalizedString(@"kProposalSubmitTipTxOK", @"创建提案成功。")];
            //  刷新界面。
            [self queryAllProposals:nil];
        }];
    }else{
        //  普通交易
        //  请求网络广播
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] proposalUpdate:opdata] then:(^id(id data) {
            [self hideBlockView];
            if (isRemove){
                [OrgUtils makeToast:NSLocalizedString(@"kProposalSubmitTxTipsRemoveApprovalOK", @"移除授权成功。")];
            }else{
                [OrgUtils makeToast:NSLocalizedString(@"kProposalSubmitTxTipsAddApprovalOK", @"添加授权成功。")];
            }
            //  [统计]
            [OrgUtils logEvents:@"txProposalUpdateFullOK" params:@{@"account":fee_paying_account}];
            //  刷新
            [self queryAllProposals:nil];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txProposalUpdateFailed" params:@{@"account":fee_paying_account}];
            return nil;
        })];
    }
}

/**
 *  事件 - 删除提案 TODO:fowallet 暂不支持
 */
- (void)onButtonClicked_Delete:(UIButton*)button
{
    id proposal = [_dataArray objectAtIndex:button.tag];
    assert(proposal);
    //  TODO:fowallet进行中
    [OrgUtils makeToast:[NSString stringWithFormat:@"delete %@", proposal[@"id"]]];
}

@end
