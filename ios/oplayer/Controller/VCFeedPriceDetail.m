//
//  VCFeedPriceDetail.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCFeedPriceDetail.h"
#import "BitsharesClientManager.h"
#import "ViewCallOrderInfoCell.h"
#import "MBProgressHUDSingleton.h"
#import "OrgUtils.h"
#import "TradingPair.h"

#import "VCCommonLogic.h"

#import "VCBtsaiWebView.h"
#import "ViewFeedPriceDataCell.h"

@interface VCFeedPriceDetail ()
{
    NSArray*    _assetList;
}

@end

@implementation VCFeedPriceDetail

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
        return [[VCFeedPriceDetailSubPage alloc] initWithOwner:self asset:asset];
    })];
}

- (void)viewDidLoad
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    _assetList = [[chainMgr getDetailFeedPriceSymbolList] ruby_map:(^id(id symbol) {
        return [chainMgr getAssetBySymbol:symbol];
    })];
    
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  REMARK：请求第一页数据
    [self queryDetailFeedInfos:1];
}

- (void)queryDetailFeedInfos:(NSInteger)tag
{
    id asset = [_assetList objectAtIndex:tag-1];
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];

    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
    [[[chainMgr queryAssetData:asset[@"id"]] then:^id(id assetData) {
        if (!assetData || [assetData isKindOfClass:[NSNull class]]) {
            [self hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"kNormalErrorInvalidArgs", @"无效参数。")];
            return nil;
        }
        
        //  1、查询喂价者信息
        id queryPublisherInfo;
        EBitsharesFeedPublisherType publisher_type;
        NSInteger flags = [[[assetData objectForKey:@"options"] objectForKey:@"flags"] integerValue];
        if ((flags & ebat_witness_fed_asset) != 0) {
            //  由见证人提供喂价
            queryPublisherInfo = [chainMgr queryActiveWitnessDataList];
            publisher_type = ebfpt_witness;
        } else if ((flags & ebat_committee_fed_asset) != 0) {
            //  由理事会成员提供喂价
            queryPublisherInfo = [chainMgr queryActiveCommitteeDataList];
            publisher_type = ebfpt_committee;
        } else {
            //  由指定账号提供喂价
            queryPublisherInfo = [NSNull null];
            publisher_type = ebfpt_custom;
        }
        
        //  2、查询喂价信息
        WsPromise* queryFeedDataPromise = [[api exec:@"get_objects" params:@[@[[assetData objectForKey:@"bitasset_data_id"]]]] then:(^id(id data) {
            return [data objectAtIndex:0];
        })];
        
        return [[WsPromise all:@[queryPublisherInfo, queryFeedDataPromise]] then:^id(id data_array) {
            id feed_infos = [data_array objectAtIndex:1];
            id feeds = [feed_infos objectForKey:@"feeds"];
            
            NSMutableDictionary* idHash = [NSMutableDictionary dictionary];
            NSMutableArray* active_publisher_ids = [NSMutableArray array];
            if (publisher_type == ebfpt_witness) {
                for (id src in [data_array objectAtIndex:0]) {
                    id account_id = [src objectForKey:@"witness_account"];
                    [active_publisher_ids addObject:account_id];
                    [idHash setObject:@YES forKey:account_id];
                }
            } else if (publisher_type == ebfpt_committee) {
                for (id src in [data_array objectAtIndex:0]) {
                    id account_id = [src objectForKey:@"committee_member_account"];
                    [active_publisher_ids addObject:account_id];
                    [idHash setObject:@YES forKey:account_id];
                }
            } else {
                for (id ary in feeds) {
                    id account_id = [ary objectAtIndex:0];
                    [active_publisher_ids addObject:account_id];
                    [idHash setObject:@YES forKey:account_id];
                }
            }
            
            //  查询依赖的账号信息
            return [[chainMgr queryAllAccountsInfo:[idHash allKeys]] then:(^id(id accounts_hash) {
                [self onQueryFeedInfoResponsed:feed_infos activePublisherIds:active_publisher_ids publisher_type:publisher_type tag:tag];
                [self hideBlockView];
                return nil;
            })];
        }];
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

- (void)onPageChanged:(NSInteger)tag
{
    NSLog(@"onPageChanged: %@", @(tag));
    
    //  gurad
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]){
        return;
    }
    
    [self queryDetailFeedInfos:tag];
}

- (void)onQueryFeedInfoResponsed:(id)data
              activePublisherIds:(NSArray*)active_publisher_ids
                  publisher_type:(EBitsharesFeedPublisherType)publisher_type tag:(NSInteger)tag
{
    if (_subvcArrays){
        VCFeedPriceDetailSubPage* vc = [_subvcArrays objectAtIndex:tag-1];
        [vc onQueryFeedInfoResponsed:data
                  activePublisherIds:active_publisher_ids
                      publisher_type:publisher_type];
    }
}

@end

@interface VCFeedPriceDetailSubPage ()
{
    __weak VCBase*              _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    NSDictionary*               _asset;
    EBitsharesFeedPublisherType _publisher_type;    //  类型
    
    UITableViewBase*            _mainTableView;
    
    NSMutableArray*             _dataCallOrders;
    NSDecimalNumber*            _feedPriceInfo; //  当前喂价（可能为nil，没有达到有效的喂价人数。）
}

@end

@implementation VCFeedPriceDetailSubPage

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _dataCallOrders = nil;
    _feedPriceInfo = nil;
    _asset = nil;
    _owner = nil;
}

- (id)initWithOwner:(VCBase*)owner asset:(NSDictionary*)asset
{
    self = [super init];
    if (self) {
        // Custom initialization
        _owner = owner;
        _asset = asset;
        _dataCallOrders = [NSMutableArray array];
        _feedPriceInfo = nil;
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
}

- (void)onQueryFeedInfoResponsed:(id)bitAssetData
              activePublisherIds:(NSArray*)active_publisher_ids
                  publisher_type:(EBitsharesFeedPublisherType)publisher_type
{
    //  clear
    [_dataCallOrders removeAllObjects];
    
    //  type
    _publisher_type = publisher_type;
    
    //  calc current feed
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    id bitAssetDataOptions = [bitAssetData objectForKey:@"options"];
    id short_backing_asset_id = [bitAssetDataOptions objectForKey:@"short_backing_asset"];
    id asset_id = [_asset objectForKey:@"id"];
    NSInteger asset_precision = [[_asset objectForKey:@"precision"] integerValue];
    assert([[bitAssetData objectForKey:@"asset_id"] isEqualToString:asset_id]);
    id sba_asset = [chainMgr getChainObjectByID:short_backing_asset_id];
    NSInteger sba_asset_precision = [[sba_asset objectForKey:@"precision"] integerValue];
    NSInteger feed_lifetime_sec = [[bitAssetDataOptions objectForKey:@"feed_lifetime_sec"] integerValue];
    
    id curr_feed_price_item = [[bitAssetData objectForKey:@"current_feed"] objectForKey:@"settlement_price"];
    _feedPriceInfo = [OrgUtils calcPriceFromPriceObject:curr_feed_price_item
                                                base_id:short_backing_asset_id
                                         base_precision:sba_asset_precision
                                        quote_precision:asset_precision
                                                 invert:NO roundingMode:NSRoundDown set_divide_precision:YES];
    
    //  calc feed detail
    NSMutableDictionary* publishedAccountHash = [NSMutableDictionary dictionary];
    id feeds = [bitAssetData objectForKey:@"feeds"];
    if (feeds && [feeds count] > 0){
        NSMutableArray* missed_list = [NSMutableArray array];
        NSMutableArray* expired_list = [NSMutableArray array];
        NSDate* now = [NSDate date];
        NSTimeInterval now_ts = [now timeIntervalSince1970];
        
        id percentHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                   scale:4
                                                                        raiseOnExactness:NO
                                                                         raiseOnOverflow:NO
                                                                        raiseOnUnderflow:NO
                                                                     raiseOnDivideByZero:NO];
        for (id feed_item_ary in feeds) {
            id publisher_account_id = [feed_item_ary objectAtIndex:0];
            assert(publisher_account_id);
            [publishedAccountHash setObject:@YES forKey:publisher_account_id];
            
            id feed_info_ary = [feed_item_ary objectAtIndex:1];
            id publish_date = [feed_info_ary objectAtIndex:0];
            
            //  REMARK：指定喂价者多情况下，feed中永远存在数据，需要主动判断是否过期。见证人和理事会的情况下过期会自动从feed列表剔除。
            BOOL expired = NO;
            if (_publisher_type == ebfpt_custom) {
                NSTimeInterval publish_date_ts = [OrgUtils parseBitsharesTimeString:publish_date];
                NSInteger diff_ts = (NSInteger)MAX(now_ts - publish_date_ts, 0);
                if (diff_ts >= feed_lifetime_sec) {
                    expired = YES;
                }
            }
            
            id feed_data = [feed_info_ary objectAtIndex:1];
            
            id name = [[chainMgr getChainObjectByID:publisher_account_id] objectForKey:@"name"];
            id n_price = [OrgUtils calcPriceFromPriceObject:feed_data[@"settlement_price"]
                                                    base_id:short_backing_asset_id
                                             base_precision:sba_asset_precision
                                            quote_precision:asset_precision
                                                     invert:NO roundingMode:NSRoundDown set_divide_precision:YES];
            
            NSDecimalNumber* change;
            if (_feedPriceInfo) {
                id rate = [n_price decimalNumberByDividingBy:_feedPriceInfo withBehavior:percentHandler];
                rate = [rate decimalNumberBySubtracting:[NSDecimalNumber one] withBehavior:percentHandler];
                change = [rate decimalNumberByMultiplyingByPowerOf10:2 withBehavior:percentHandler];
            } else {
                //  REMARK：没有“当前喂价”信息，不计算偏移量。
                change = [NSDecimalNumber zero];
            }
            
            if (n_price) {
                id item = @{@"name":name, @"price":n_price, @"diff":change, @"date":publish_date, @"expired":@(expired)};
                if (expired) {
                    [expired_list addObject:item];
                } else {
                    [_dataCallOrders addObject:item];
                }
            } else {
                //  REMARK：手动指定喂价者，但没发布信息。计算的价格为 nil。
                [missed_list addObject:@{@"name":name, @"miss":@YES}];
            }
        }
        
        //  有效的喂价：按照价格降序排列
        [_dataCallOrders sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [[obj2 objectForKey:@"price"] compare:[obj1 objectForKey:@"price"]];
        })];
        
        //  添加过期的喂价（仅手动指定发布者的时候才存在）
        [_dataCallOrders addObjectsFromArray:expired_list];
        
        //  添加未发布的喂价者信息
        [_dataCallOrders addObjectsFromArray:missed_list];
    }
    for (id account_id in active_publisher_ids) {
        if (![[publishedAccountHash objectForKey:account_id] boolValue]){
            id name = [[chainMgr getChainObjectByID:account_id] objectForKey:@"name"];
            [_dataCallOrders addObject:@{@"name":name, @"miss":@YES}];
        }
    }
    
    //  动态设置UI的可见性（没有抵押信息的情况几乎不存在）
    [_mainTableView reloadData];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger n = [_dataCallOrders count];
    if (n > 0){
        //  rows + title
        return n + 1;
    }else{
        return 0;
    }
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
        if (_feedPriceInfo) {
             titleLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcFeedCurrentFeedPrice", @"当前喂价"), [OrgUtils formatFloatValue:_feedPriceInfo]];
        } else {
            titleLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcFeedCurrentFeedPrice", @"当前喂价"), [NSLocalizedString(@"kVcFeedNoData", @"未发布") uppercaseString]];
        }
        
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
    return 28.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_feed_price_detail";
    
    ViewFeedPriceDataCell* cell = (ViewFeedPriceDataCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewFeedPriceDataCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor clearColor];
    }
    cell.showCustomBottomLine = NO;
    if (indexPath.row == 0){
        id name;
        if (_publisher_type == ebfpt_witness) {
            name = NSLocalizedString(@"kVcFeedWitnessName", @"见证人");
        } else if (_publisher_type == ebfpt_committee) {
            name = NSLocalizedString(@"kVcFeedPublisherCommitteeName", @"理事会");
        } else {
            name = NSLocalizedString(@"kVcFeedPublisherCustom", @"喂价者");
        }
        [cell setItem:@{@"title":@YES, @"name":name}];
    }else{
        [cell setItem:[_dataCallOrders objectAtIndex:indexPath.row - 1]];
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

