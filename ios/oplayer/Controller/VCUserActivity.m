//
//  VCUserActivity.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCUserActivity.h"
#import "BitsharesClientManager.h"
#import "ViewUserActivityInfoCell.h"
#import "OrgUtils.h"
#import "viewLoading.h"

@interface VCUserActivity ()
{
    NSDictionary*           _accountInfo;
    
    UILabel*                _lbEmpty;
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    NSInteger               _loadStartID;
    BOOL                    _loading;
}

@end

@implementation VCUserActivity

-(void)dealloc
{
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithAccountInfo:(NSDictionary*)accountInfo
{
    self = [super init];
    if (self){
        _accountInfo = accountInfo;
        _dataArray = [NSMutableArray array];
        _loadStartID = 0;
        _loading = NO;
    }
    return self;
}

/**
 *  (public) 合并账户历史中的订单成交条目 TODO:fowallet 未完成
 */
- (NSArray*)mergeFillOrderHistory:(NSArray*)data_array
{
    if (!data_array || [data_array count] <= 0){
        return data_array;
    }

    
//    NSMutableDictionary* last_fill_order_opdata_item = nil;
//    unsigned long long pays_ammount = 0;
//    unsigned long long receives_amount = 0;
//    NSString* last_order_id = nil;
//    NSString* last_pays_asset_id;
//    NSString* last_receives_asset_id;
//    id new_array = [NSMutableArray array];
//    for (id history in data) {
//        id op = [history objectForKey:@"op"];
//        NSInteger optype = [[op objectAtIndex:0] integerValue];
//        if (optype == ebo_fill_order){
//            id opdata = [op objectAtIndex:1];
//
//            if (!last_fill_order_opdata_item){
//                last_fill_order_opdata_item = [opdata mutableCopy];
//                last_order_id = opdata[@"order_id"];
//                id pays = opdata[@"pays"];
//                id receives = opdata[@"receives"];
//                last_pays_asset_id = pays[@"asset_id"];
//                last_receives_asset_id = receives[@"asset_id"];
//            }else{
//                id order_id = opdata[@"order_id"];
//                id pays = opdata[@"pays"];
//                id receives = opdata[@"receives"];
//                id pays_asset_id = pays[@"asset_id"];
//                id receives_asset_id = receives[@"asset_id"];
//                if ([order_id isEqualToString:last_order_id] &&
//                    [pays_asset_id isEqualToString:last_pays_asset_id] &&
//                    [receives_asset_id isEqualToString:last_receives_asset_id])
//                {
//                    pays_ammount += [pays[@"amount"] unsignedLongLongValue];
//                    receives_amount += [receives[@"amount"] unsignedLongLongValue];
//                    last_fill_order_opdata_item = opdata;
//                }
//                else
//                {
//                    //  ...
//                }
//            }
//        }else{
//            [new_array addObject:history];
//        }
//    }
//
    return data_array;
}

- (void)onQueryAccountHistoryDetailResponsed:(id)data
{
    _loading = NO;
    
    [_dataArray removeAllObjects];
    
    if (!data || [data count] <= 0){
        [self refreshView];
        return;
    }
    
    data = [self mergeFillOrderHistory:data];
    
    //  TODO:fowallet 加载更多（待处理。）
//    id first_item = [data firstObject];
//    NSInteger history_id = [[[[first_item objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id assetBasePriority = [chainMgr genAssetBasePriorityHash];
    for (id history in data) {
        id block_num = [history objectForKey:@"block_num"];
        id block_header = [chainMgr getBlockHeaderInfoByBlockNumber:block_num];
        assert(block_header);
        
        //  根据操作op构造显示内容
        NSString* transferName = nil;
        NSString* mainDesc = @"未知操作内容。。。";
        UIColor* transferNameColor = nil;
        id op = [history objectForKey:@"op"];
        NSInteger optype = [[op objectAtIndex:0] integerValue];
        id opdata = [op objectAtIndex:1];
        
        //  处理要显示的操作类型 TODO:fowallet 待完善添加支持更多。
        //  TODO:fowallet 各种细节优化、比如更新账户 投票独立出来 等等。买单卖单独立等等。
        //  TODO:fowallet 考虑着色
        switch (optype) {
            case ebo_transfer:
            {
                transferName = NSLocalizedString(@"kVcActivityTypeTransfer", @"转账");
                id from = [[chainMgr getChainObjectByID:opdata[@"from"]] objectForKey:@"name"];
                id to = [[chainMgr getChainObjectByID:opdata[@"to"]] objectForKey:@"name"];
                id amount = opdata[@"amount"];
                id asset = [chainMgr getChainObjectByID:amount[@"asset_id"]];
                id num = [OrgUtils formatAssetString:amount[@"amount"] asset:asset];
                id str_amount = [NSString stringWithFormat:@"%@%@", num, asset[@"symbol"]];
                mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescTransfer", @"%@ 转账 %@ 到 %@。"), from, str_amount, to];
            }
                break;
            case ebo_limit_order_create:
            {
                //  luxs 提交卖单，以101.9134 SEED/CNY的价格卖出 0.0993 CNY
                id user = [[chainMgr getChainObjectByID:opdata[@"seller"]] objectForKey:@"name"];
                
                //  @{@"issell":@(issell), @"base":base_asset, @"quote":quote_asset, @"n_base":n_base, @"n_quote":n_quote, @"n_price":n_price};
                id infos = [OrgUtils calcOrderDirectionInfos:assetBasePriority
                                              pay_asset_info:opdata[@"amount_to_sell"]
                                          receive_asset_info:opdata[@"min_to_receive"]];
                
                id base_asset = infos[@"base"];
                id quote_asset = infos[@"quote"];
                id n_price = infos[@"n_price"];
                id n_quote = infos[@"n_quote"];
                id str_price = [NSString stringWithFormat:@"%@%@/%@",n_price, base_asset[@"symbol"], quote_asset[@"symbol"]];
                id str_amount = [NSString stringWithFormat:@"%@%@", n_quote, quote_asset[@"symbol"]];
                
                if ([infos[@"issell"] boolValue]){
                    transferName = NSLocalizedString(@"kVcActivityTypeCreateSellOrder", @"创建卖单");
                    transferNameColor = [ThemeManager sharedThemeManager].sellColor;
                    mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescCreateSellOrder", @"%@ 提交卖单，以 %@ 的价格卖出 %@。"),
                                user, str_price, str_amount];
                }else{
                    transferName = NSLocalizedString(@"kVcActivityTypeCreateBuyOrder", @"创建买单");
                    transferNameColor = [ThemeManager sharedThemeManager].buyColor;
                    mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescCreateBuyOrder", @"%@ 提交买单，以 %@ 的价格买入 %@。"),
                                user, str_price, str_amount];
                }
            }
                break;
            case ebo_limit_order_cancel:
            {
                transferName = NSLocalizedString(@"kVcActivityTypeCancelOrder", @"取消订单");
                id user = [[chainMgr getChainObjectByID:opdata[@"fee_paying_account"]] objectForKey:@"name"];
                mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescCancelOrder", @"%@ 取消了限价单 #%@。"),
                            user, [[opdata[@"order"] componentsSeparatedByString:@"."] lastObject]];
            }
                break;
            case ebo_call_order_update:
            {
                transferName = NSLocalizedString(@"kVcActivityTypeUpdatePosition", @"调整债仓");
                
                id user = [[chainMgr getChainObjectByID:opdata[@"funding_account"]] objectForKey:@"name"];
                
                //  REMARK：这2个字段可能为负数。
                id collateral = opdata[@"delta_collateral"];
                id debt = opdata[@"delta_debt"];
                
                id collateral_asset = [chainMgr getChainObjectByID:collateral[@"asset_id"]];
                id debt_asset = [chainMgr getChainObjectByID:debt[@"asset_id"]];
                
                id collateral_num = [OrgUtils formatAssetString:collateral[@"amount"] asset:collateral_asset];
                id debt_num = [OrgUtils formatAssetString:debt[@"amount"] asset:debt_asset];
                
                id str_collateral = [NSString stringWithFormat:@"%@%@", collateral_num, collateral_asset[@"symbol"]];
                id str_debt = [NSString stringWithFormat:@"%@%@", debt_num, debt_asset[@"symbol"]];
                
                mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescUpdatePosition", @"%@ 更新保证金 %@，借出 %@。"),
                            user, str_collateral, str_debt];
            }
                break;
            case ebo_fill_order:
            {
                transferName = NSLocalizedString(@"kVcActivityTypeFillOrder", @"订单成交");
                
                id user = [[chainMgr getChainObjectByID:opdata[@"account_id"]] objectForKey:@"name"];
                BOOL isCallOrder = [[[opdata[@"order_id"] componentsSeparatedByString:@"."] objectAtIndex:1] integerValue] == ebot_call_order;
                
                //  @{@"issell":@(issell), @"base":base_asset, @"quote":quote_asset, @"n_base":n_base, @"n_quote":n_quote, @"n_price":n_price};
                id infos = [OrgUtils calcOrderDirectionInfos:assetBasePriority
                                              pay_asset_info:opdata[@"pays"]
                                          receive_asset_info:opdata[@"receives"]];
                
                id base_asset = infos[@"base"];
                id quote_asset = infos[@"quote"];
                id n_price = infos[@"n_price"];
                id n_quote = infos[@"n_quote"];
                id str_price = [NSString stringWithFormat:@"%@%@/%@", n_price, base_asset[@"symbol"], quote_asset[@"symbol"]];
                id str_amount = [NSString stringWithFormat:@"%@%@", n_quote, quote_asset[@"symbol"]];
                
                if ([infos[@"issell"] boolValue]){
                    mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescFillSellOrder", @"%@ 以 %@ 的价格卖出 %@。"),
                                user, str_price, str_amount];
                }else{
                    mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescFillBuyOrder", @"%@ 以 %@ 的价格买入 %@。"),
                                user, str_price, str_amount];
                }
                if (isCallOrder){
                    transferNameColor = [ThemeManager sharedThemeManager].callOrderColor;
                }
            }
                break;
            case ebo_account_create:
            {
                transferName = NSLocalizedString(@"kVcActivityTypeCreateAccount", @"创建帐号");
                id user = [[chainMgr getChainObjectByID:opdata[@"registrar"]] objectForKey:@"name"];
                mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescCreateAccount", @"%@ 创建了帐号 %@。"), user, opdata[@"name"]];
            }
                break;
            case ebo_account_update:
            {
                transferName = NSLocalizedString(@"kVcActivityTypeUpdateAccount", @"更新账户");
                id user = [[chainMgr getChainObjectByID:opdata[@"account"]] objectForKey:@"name"];
                mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescUpdateAccount", @"%@ 更新了账户信息。"), user];
            }
                break;
            case ebo_account_upgrade:
            {
                if ([opdata[@"upgrade_to_lifetime_member"] boolValue]){
                    transferName = NSLocalizedString(@"kVcActivityTypeUpgradeAccount", @"升级账户");
                    id user = [[chainMgr getChainObjectByID:opdata[@"account_to_upgrade"]] objectForKey:@"name"];
                    mainDesc = [NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescUpgradeAccount", @"%@ 升级了终身会员。"), user];
                }
            }
                break;
            case ebo_proposal_create:   //  22
            {
                transferName = NSLocalizedString(@"kVcActivityTypeCreateProposal", @"创建提案");
                mainDesc = NSLocalizedString(@"kVcActivityDescCreateProposal", @"创建提案。");
//                for (id proposed_op in opdata[@"proposed_ops"]) {
//                    [proposed_op objectForKey:@"op"];
//                }
//                mainDesc = [NSString stringWithFormat:@"%@ 升级了终身会员。", user];
            }
                break;
            case ebo_proposal_update:   //  23
            {
                transferName = NSLocalizedString(@"kVcActivityTypeUpdateProposal", @"更新提案");
                mainDesc =[NSString stringWithFormat:NSLocalizedString(@"kVcActivityDescUpdateProposal", @"更新提案。#%@"), [[opdata[@"proposal"] componentsSeparatedByString:@"."] lastObject]];
            }
                break;
            default:
            {
                NSLog(@"未知操作%@", @(optype));
            }
                break;
        }
        
        //  REMARK：未知操作不显示，略过。
        if (!transferName){
            continue;
        }
        
        if (transferNameColor){
            [_dataArray addObject:@{@"block_time":[block_header objectForKey:@"timestamp"] ?: @"", @"history":history, @"typename":transferName, @"desc":mainDesc, @"typecolor":transferNameColor}];
        }else{
            [_dataArray addObject:@{@"block_time":[block_header objectForKey:@"timestamp"] ?: @"", @"history":history, @"typename":transferName, @"desc":mainDesc}];
        }
        
    }
    
    //  刷新
    [self refreshView];
}

- (WsPromise*)onGetAccountHistoryResponsed:(id)data_array
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    NSMutableDictionary* block_num_hash = [NSMutableDictionary dictionary];
    NSMutableDictionary* asset_id_hash = [NSMutableDictionary dictionary];
    NSMutableDictionary* account_id_hash = [NSMutableDictionary dictionary];
    for (id history in data_array) {
        block_num_hash[[history objectForKey:@"block_num"]] = @YES;
        id op = [history objectForKey:@"op"];
        id op_data = [op objectAtIndex:1];
        //  手续费资产查询
        id fee = [op_data objectForKey:@"fee"];
        if (fee){
            asset_id_hash[fee[@"asset_id"]] = @YES;
        }
        //  获取每项操作需要额外查询到信息（资产ID、帐号ID等）
        switch ([[op objectAtIndex:0] integerValue]) {
            case ebo_transfer:              //  0
            {
                account_id_hash[op_data[@"from"]] = @YES;
                account_id_hash[op_data[@"to"]] = @YES;
                asset_id_hash[op_data[@"amount"][@"asset_id"]] = @YES;
            }
                break;
            case ebo_limit_order_create:    //  1
            {
                account_id_hash[op_data[@"seller"]] = @YES;
                asset_id_hash[op_data[@"amount_to_sell"][@"asset_id"]] = @YES;
                asset_id_hash[op_data[@"min_to_receive"][@"asset_id"]] = @YES;
            }
                break;
            case ebo_limit_order_cancel:    //  2
            {
                account_id_hash[op_data[@"fee_paying_account"]] = @YES;
            }
                break;
            case ebo_call_order_update:     //  3
            {
                account_id_hash[op_data[@"funding_account"]] = @YES;
                asset_id_hash[op_data[@"delta_collateral"][@"asset_id"]] = @YES;
                asset_id_hash[op_data[@"delta_debt"][@"asset_id"]] = @YES;
            }
                break;
            case ebo_fill_order:            //  4
            {
                account_id_hash[op_data[@"account_id"]] = @YES;
                asset_id_hash[op_data[@"pays"][@"asset_id"]] = @YES;
                asset_id_hash[op_data[@"receives"][@"asset_id"]] = @YES;
            }
                break;
            case ebo_account_create:        //  5
            {
                account_id_hash[op_data[@"registrar"]] = @YES;
            }
                break;
            case ebo_account_update:        //  6
            {
                account_id_hash[op_data[@"account"]] = @YES;
            }
                break;
            case ebo_account_upgrade:       //  8
            {
                account_id_hash[op_data[@"account_to_upgrade"]] = @YES;
            }
                break;
            default:
                //  TODO:fowallet 其他类型的操作 额外处理。重要！！！！
                break;
        }
    }
    //  额外查询 各种操作以来的资产信息、帐号信息、时间信息等
    NSArray* block_num_list = [block_num_hash allKeys];
    NSArray* asset_id_list = [asset_id_hash allKeys];
    NSArray* account_id_list = [account_id_hash allKeys];
    
    id p1 = [chainMgr queryAllAssetsInfo:asset_id_list];
    id p2 = [chainMgr queryAllAccountsInfo:account_id_list];
    id p3 = [chainMgr queryAllBlockHeaderInfos:block_num_list skipQueryCache:NO];
    
    //  这里面引用的变量必须是 weak 的，不然该 vc 没法释放。
    __weak typeof(self) weak_self = self;
    return [[WsPromise all:@[p1, p2, p3]] then:(^id(id data) {
        if (weak_self){
            [weak_self onQueryAccountHistoryDetailResponsed:data_array];
        }
        return @YES;
    })];
}

- (void)queryAccountHistory
{
    //  处理加载中标记
    if (_loading){
        return;
    }
    _loading = YES;
    
    GrapheneApi* api_history = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_history;
    
    //  !!!! TODO:fowallet可以历史记录，方便继续查询。考虑添加。 if (history && history.size) most_recent = history.first().get("id");
    //  查询最新的 100 条记录。
    id stop = [NSString stringWithFormat:@"1.%@.0", @(ebot_operation_history)];
    id start = [NSString stringWithFormat:@"1.%@.%@", @(ebot_operation_history), @(_loadStartID)];
    //  start - 从指定ID号往前查询（包含该ID号），如果指定ID为0，则从最新的历史记录往前查询。结果包含 start。
    //  stop  - 指定停止查询ID号（结果不包含该ID），如果指定为0，则查询到最早的记录位置（or达到limit停止。）结果不包含该 stop ID。
//    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  这里面引用的变量必须是 weak 的，不然该 vc 没法释放。
    __weak id this = self;
    WsPromise* p = [api_history exec:@"get_account_history" params:@[[_accountInfo objectForKey:@"id"], stop, @100, start]];
    [[p then:(^id(id data_array) {
        if (this){
            return [this onGetAccountHistoryResponsed:data_array];
        }
        return nil;
    })] catch:(^id(id error) {
        _loading = NO;
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    CGRect rect = [self rectWithoutNaviAndPageBar];
    
    //  UI - 列表
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [[UILabel alloc] initWithFrame:rect];
    _lbEmpty.lineBreakMode = NSLineBreakByWordWrapping;
    _lbEmpty.numberOfLines = 1;
    _lbEmpty.contentMode = UIViewContentModeCenter;
    _lbEmpty.backgroundColor = [UIColor clearColor];
    _lbEmpty.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _lbEmpty.textAlignment = NSTextAlignmentCenter;
    _lbEmpty.font = [UIFont boldSystemFontOfSize:13];
    _lbEmpty.text = NSLocalizedString(@"kVcAssetTipNoActivity", @"没有任何活动信息");
    [self.view addSubview:_lbEmpty];
    _lbEmpty.hidden = !_mainTableView.hidden;
    
    //  查询
    [self queryAccountHistory];
}

- (void)refreshView
{
    _mainTableView.hidden = [_dataArray count] <= 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_loading){
        return [_dataArray count] + 1;
    }
    return [_dataArray count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= [_dataArray count]){
        //  loading cell
        return tableView.rowHeight;
    }
    return [ViewUserActivityInfoCell getCellHeight:[_dataArray objectAtIndex:indexPath.row]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= [_dataArray count]){
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];
        ViewLoading* viewLoading = [[ViewLoading alloc] initWithText:NSLocalizedString(@"kVcAssetTipNowLoading", @"正在加载中...")];
        [cell.contentView addSubview:viewLoading];
        return cell;
    }else{
        static NSString* identify = @"id_user_activity";
        ViewUserActivityInfoCell* cell = (ViewUserActivityInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
        if (!cell)
        {
            cell = [[ViewUserActivityInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
        }
        cell.showCustomBottomLine = YES;
        [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
        return cell;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
