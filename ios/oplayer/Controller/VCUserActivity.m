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
    for (id history in data) {
        id block_num = [history objectForKey:@"block_num"];
        id block_header = [chainMgr getBlockHeaderInfoByBlockNumber:block_num];
        assert(block_header);
        
        //  根据操作op构造显示内容
        id op = [history objectForKey:@"op"];
        NSInteger optype = [[op objectAtIndex:0] integerValue];
        id opdata = [op objectAtIndex:1];
        id opresult = [history objectForKey:@"result"];
        
        id uidata = [OrgUtils processOpdata2UiData:optype opdata:opdata opresult:opresult isproposal:NO];
        
        //  REMARK：未知操作不显示，略过。
        if (!uidata){
            continue;
        }
        
        [_dataArray addObject:@{@"block_time":[block_header objectForKey:@"timestamp"] ?: @"",
                                @"history":history,
                                @"typename":uidata[@"name"],
                                @"desc":uidata[@"desc"],
                                @"typecolor":uidata[@"color"]}];
    }
    
    //  刷新
    [self refreshView];
}

- (WsPromise*)onGetAccountHistoryResponsed:(id)data_array
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    NSMutableDictionary* block_num_hash = [NSMutableDictionary dictionary];
    NSMutableDictionary* query_ids = [NSMutableDictionary dictionary];
    for (id history in data_array) {
        block_num_hash[[history objectForKey:@"block_num"]] = @YES;
        id op = [history objectForKey:@"op"];
        id op_data = [op objectAtIndex:1];
        [OrgUtils extractObjectID:[[op objectAtIndex:0] integerValue] opdata:op_data container:query_ids];
    }
    
    //  额外查询 各种操作依赖的资产信息、帐号信息、时间信息等
    id p1 = [chainMgr queryAllGrapheneObjects:[query_ids allKeys]];
    id p2 = [chainMgr queryAllBlockHeaderInfos:[block_num_hash allKeys] skipQueryCache:NO];
    
    //  这里面引用的变量必须是 weak 的，不然该 vc 没法释放。
    __weak typeof(self) weak_self = self;
    return [[WsPromise all:@[p1, p2]] then:(^id(id data) {
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
