//
//  VCCallOrderRanking.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCCallOrderRanking.h"
#import "BitsharesClientManager.h"
#import "ViewCallOrderInfoCell.h"
#import "MBProgressHUDSingleton.h"
#import "OrgUtils.h"
#import "TradingPair.h"

#import "VCCommonLogic.h"

#import "VCBtsaiWebView.h"

@interface VCCallOrderRanking ()
{
    NSArray*    _assetList;
}

@end

@implementation VCCallOrderRanking

-(void)dealloc
{
    _assetList = nil;
}

- (NSArray*)getTitleStringArray
{
    //  TODO:fowallet 标题名字直接symbol还是需要加描述 比如 CNY排行。
    return [_assetList ruby_map:(^id(id src) {
        return [src objectForKey:@"symbol"];
    })];
}

- (NSArray*)getSubPageVCArray
{
    return [_assetList ruby_map:(^id(id asset) {
        return [[VCRankingList alloc] initWithOwner:self asset:asset];
    })];
}

- (void)viewDidLoad
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    _assetList = [[chainMgr getCallOrderRankingSymbolList] ruby_map:(^id(id symbol) {
        return [chainMgr getAssetBySymbol:symbol];
    })];
    
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  REMARK：请求第一页数据
    [self queryCallOrderData:1];
}

- (void)queryCallOrderData:(NSInteger)tag
{
    id asset = [_assetList objectAtIndex:tag-1];
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //    get_call_orders && get_full_accounts
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
    id p1 = [api exec:@"get_call_orders" params:@[[asset objectForKey:@"id"], @50]];
    id p2 = [[api exec:@"get_objects" params:@[@[[asset objectForKey:@"bitasset_data_id"]]]] then:(^id(id data) {
        return [data objectAtIndex:0];
    })];
    
    [[[WsPromise all:@[p1, p2]] then:(^id(id data) {
        id borrower_list = [data[0] ruby_map:(^id(id src) {
            return src[@"borrower"];
        })];
        return [[chainMgr queryAllAccountsInfo:borrower_list] then:(^id(id borrower_hash) {
            //  (void)borrower_hash 不需要
            [self onQueryCallOrderResponsed:data tag:tag];
            [self hideBlockView];
            return nil;
        })];
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)onPageChanged:(NSInteger)tag
{
    NSLog(@"onPageChanged: %@", @(tag));
    
    //  gurad
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]){
        return;
    }
    
    [self queryCallOrderData:tag];
}

- (void)onQueryCallOrderResponsed:(id)data tag:(NSInteger)tag
{
    if (_subvcArrays){
        VCRankingList* vc = [_subvcArrays objectAtIndex:tag-1];
        [vc onQueryCallOrderResponsed:data];
    }
}

@end

@interface VCRankingList ()
{
    __weak VCBase*      _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    NSDictionary*       _asset;
    TradingPair*        _tradingPair;
    
    UITableViewBase*    _mainTableView;
    UILabel*            _lbEmptyOrder;
    
    NSMutableArray*     _dataCallOrders;
    NSDecimalNumber*    _feedPriceInfo;
    NSDecimalNumber*    _mcr;
}

@end

@implementation VCRankingList

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbEmptyOrder = nil;
    _dataCallOrders = nil;
    _feedPriceInfo = nil;
    _mcr = nil;
    _tradingPair = nil;
    _asset = nil;
    _owner = nil;
}

- (id)initWithOwner:(VCBase*)owner asset:(NSDictionary*)asset
{
    self = [super init];
    if (self) {
        // Custom initialization
        _owner = owner;
        _tradingPair = nil;
        _asset = asset;
        _dataCallOrders = [NSMutableArray array];
        _feedPriceInfo = nil;
        _mcr = nil;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    // Do any additional setup after loading the view.
    CGRect rect = [self rectWithoutNaviAndPageBar];
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    [self.view addSubview:_mainTableView];

    _lbEmptyOrder = [[UILabel alloc] initWithFrame:rect];
    _lbEmptyOrder.lineBreakMode = NSLineBreakByWordWrapping;
    _lbEmptyOrder.numberOfLines = 1;
    _lbEmptyOrder.contentMode = UIViewContentModeCenter;
    _lbEmptyOrder.backgroundColor = [UIColor clearColor];
    _lbEmptyOrder.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _lbEmptyOrder.textAlignment = NSTextAlignmentCenter;
    _lbEmptyOrder.font = [UIFont boldSystemFontOfSize:13];
    _lbEmptyOrder.text = NSLocalizedString(@"kVcTipsNoCallOrder", @"还没有用户进行抵押");
    _lbEmptyOrder.hidden = YES;
    [self.view addSubview:_lbEmptyOrder];
}

- (void)onQueryCallOrderResponsed:(id)data
{
    //  data[0] - 抵押排行信息
    //  data[1] - 喂价信息
    [_dataCallOrders removeAllObjects];
    [_dataCallOrders addObjectsFromArray:data[0]];
    
    //  保存喂价信息、并计算喂价
    id feedPriceData = [data[1] copy];
    assert(feedPriceData);
    if (!_tradingPair){
        id short_backing_asset = [feedPriceData objectForKey:@"options"][@"short_backing_asset"];
        assert([[feedPriceData objectForKey:@"asset_id"] isEqualToString:[_asset objectForKey:@"id"]]);
        _tradingPair = [[TradingPair alloc] initWithBaseID:[feedPriceData objectForKey:@"asset_id"] quoteId:short_backing_asset];
    }
    _feedPriceInfo = [_tradingPair calcShowFeedInfo:@[feedPriceData]];
    
    //  计算MCR
    id mcr = [[feedPriceData objectForKey:@"current_feed"] objectForKey:@"maintenance_collateral_ratio"];
    _mcr = [NSDecimalNumber decimalNumberWithMantissa:[mcr unsignedLongLongValue] exponent:-3 isNegative:NO];
    
    //  动态设置UI的可见性（没有抵押信息的情况几乎不存在）
    if ([_dataCallOrders count] > 0){
        _mainTableView.hidden = NO;
        _lbEmptyOrder.hidden = YES;
        [_mainTableView reloadData];
    }else{
        _mainTableView.hidden = YES;
        _lbEmptyOrder.hidden = NO;
    }
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataCallOrders count];
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    //  没有数据的时候则没有 header view
    if ([_dataCallOrders count] <= 0){
        return 0.01f;
    }
    return 44.0f;
}

/**
 *  (private) 帮助按钮点击
 */
- (void)onTipButtonClicked:(UIButton*)sender
{
    if (!_owner){
        return;
    }
    //  [统计]
    [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_feedprice"}];
    VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:@"https://btspp.io/qam.html#qa_feedprice"];
    vc.title = NSLocalizedString(@"kVcTitleWhatIsFeedPrice", @"什么是喂价？");
    [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if ([_dataCallOrders count] <= 0){
        return [[UIView alloc] init];
    }else{
        CGFloat fWidth = self.view.bounds.size.width;
        CGFloat xOffset = tableView.layoutMargins.left;
        UIView* myView = [[UIView alloc] init];
        myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 44)];
        titleLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:16];
        
        id asset = [[ChainObjectManager sharedChainObjectManager] getAssetBySymbol:[_asset objectForKey:@"symbol"]];
        assert(asset);
        titleLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcRankCurrentFeedPrice", @"当前喂价"), [OrgUtils formatFloatValue:_feedPriceInfo]];
        
        [myView addSubview:titleLabel];
        
        //  是否有帮助按钮
        UIButton* btnTips = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];
        CGSize btn_size = btn_image.size;
        [btnTips setBackgroundImage:btn_image forState:UIControlStateNormal];
        btnTips.userInteractionEnabled = YES;
        [btnTips addTarget:self action:@selector(onTipButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        btnTips.frame = CGRectMake(fWidth - btn_image.size.width - xOffset, (44 - btn_size.height) / 2, btn_size.width, btn_size.height);
        btnTips.tag = section;
        btnTips.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
        
        [myView addSubview:btnTips];
        
        return myView;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28.0f * 3;

    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_callorder_rank";
    
    ViewCallOrderInfoCell* cell = (ViewCallOrderInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewCallOrderInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor clearColor];
    }
    
    cell.debt_precision = _tradingPair.basePrecision;
    cell.collateral_precision = _tradingPair.quotePrecision;
    cell.mcr = _mcr;
    cell.showCustomBottomLine = YES;
    cell.feedPriceInfo = _feedPriceInfo;
    [cell setItem:[_dataCallOrders objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        id item = [_dataCallOrders objectAtIndex:indexPath.row];
        assert(item);
        [VCCommonLogic viewUserAssets:_owner account:[item objectForKey:@"borrower"]];
    }];
}

@end

