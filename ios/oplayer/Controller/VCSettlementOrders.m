//
//  VCSettlementOrders.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCSettlementOrders.h"
#import "ViewSettlementOrderInfoCell.h"
#import "OrgUtils.h"

@interface VCSettlementOrders ()
{
    TradingPair*            _tradingPair;
    NSDictionary*           _fullAccountInfo;
    
    __weak VCBase*          _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCSettlementOrders

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
    _tradingPair = nil;
}

- (id)initWithOwner:(VCBase*)owner tradingPair:(TradingPair*)tradingPair fullAccountInfo:(NSDictionary*)fullAccountInfo
{
    self = [super init];
    if (self){
        _owner = owner;
        _tradingPair = tradingPair;
        _fullAccountInfo = fullAccountInfo;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onQuerySettlementOrdersResponsed:(NSArray*)data_array
{
    //  更新数据
    [_dataArray removeAllObjects];
    if (data_array && [data_array count] > 0){
        [_dataArray addObjectsFromArray:data_array];
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

- (void)querySettlementOrders
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //  TODO:4.0
    [[[chainMgr querySettlementOrders:@"1.3.113" number:100] then:^id(id data_array) {
        [_owner hideBlockView];
        [self onQuerySettlementOrdersResponsed:data_array];
        return nil;
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
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
    
    //  UI - 空 TODO:4.0 lang
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有任何清算单。"];
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
    static NSString* identify = @"id_settle_order_info_cell";
    ViewSettlementOrderInfoCell* cell = (ViewSettlementOrderInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewSettlementOrderInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.showCustomBottomLine = YES;
//    cell.row = indexPath.row;
//    [cell setTagData:indexPath.row];
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
