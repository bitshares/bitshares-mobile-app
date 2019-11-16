//
//  VCOtcMerchantList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMerchantList.h"
#import "VCOtcOrders.h"
#import "VCOtcUserAuth.h"
#import "VCOtcPaymentMethods.h"

#import "ViewOtcMerchantInfoCell.h"
#import "MBProgressHUDSingleton.h"
#import "OtcManager.h"

@interface VCOtcMerchantListPages ()
{
    NSString*   _curr_asset_name;
    EOtcAdType  _default_ad_type;
}

@end

@implementation VCOtcMerchantListPages

-(void)dealloc
{
}

- (id)initWithAssetName:(NSString*)asset_name ad_type:(EOtcAdType)ad_type
{
    self = [super init];
    if (self) {
        // Custom initialization
        _curr_asset_name = asset_name;
        _default_ad_type = ad_type;
    }
    return self;
}

- (NSInteger)getTitleDefaultSelectedIndex
{
    return _default_ad_type == eoadt_user_buy ? 1 : 2;
}

- (NSArray*)getTitleStringArray
{
    //  TODO:2.9
    return @[@"我要买", @"我要卖"];
//    return [_assetList ruby_map:(^id(id src) {
//        return [src objectForKey:@"symbol"];
//    })];
}

- (NSArray*)getSubPageVCArray
{
    return @[[[VCOtcMerchantList alloc] initWithOwner:self ad_type:eoadt_user_buy],
             [[VCOtcMerchantList alloc] initWithOwner:self ad_type:eoadt_user_sell]];
}

- (void)onRightOrderButtonClicked
{
    VCBase* vc = [[VCOtcOrdersPages alloc] init];
    //  TODO:2.9
    [self pushViewController:vc vctitle:@"订单记录" backtitle:kVcDefaultBackTitleName];
}

- (void)onRightUserButtonClicked
{
    VCBase* vc = [[VCOtcUserAuth alloc] init];
    //  TODO:2.9
    [self pushViewController:vc vctitle:@"身份认证" backtitle:kVcDefaultBackTitleName];
}

- (NSString*)genTitleString
{
    return [NSString stringWithFormat:@"%@%@", _curr_asset_name, @"市场◢"];//TODO:2.9  lang
}

- (void)onTitleAssetButtonClicked:(UIButton*)sender
{
    id list = [[OtcManager sharedOtcManager].asset_list_digital ruby_map:^id(id src) {
        return [src objectForKey:@"symbol"];
    }];
    //  TODO:2.9 lang
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:@"请选择要交易的资产"
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:list
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
         if (buttonIndex != cancelIndex){
             id asset_name = [list objectAtIndex:buttonIndex];
             if (![_curr_asset_name isEqualToString:asset_name]) {
                 _curr_asset_name = asset_name;
                 [sender setTitle:[self genTitleString] forState:UIControlStateNormal];
                 [self queryCurrentPageAdList];
             }
         }
     }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  TODO:2.9 icon
    id btn1 = [self naviButtonWithImage:@"iconOrders" action:@selector(onRightOrderButtonClicked) color:theme.textColorNormal];
    id btn2 = [self naviButtonWithImage:@"iconExplorer" action:@selector(onRightUserButtonClicked) color:theme.textColorNormal];
    [self.navigationItem setRightBarButtonItems:@[btn2, btn1]];
    
    //  导航栏中间标题
    UIButton* btnAssetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    btnAssetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [btnAssetBtn setTitle:[self genTitleString] forState:UIControlStateNormal];
    [btnAssetBtn setTitleColor:[ThemeManager sharedThemeManager].textColorMain forState:UIControlStateNormal];
    btnAssetBtn.userInteractionEnabled = YES;
    [btnAssetBtn addTarget:self action:@selector(onTitleAssetButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnAssetBtn.frame = CGRectMake(0, 0, self.view.bounds.size.width, [self heightForNavigationBar]);
    self.navigationItem.titleView = btnAssetBtn;
    
    //  查询数据
    [self queryCurrentPageAdList];
}

- (void)queryCurrentPageAdList
{
    //  TODO:2.9
    VCOtcMerchantList* vc = (VCOtcMerchantList*)[self currentPage];
    if (vc) {
        [vc queryAdList:_curr_asset_name];
    }
}

- (void)onPageChanged:(NSInteger)tag
{
    NSLog(@"onPageChanged: %@", @(tag));
    
    //  gurad
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]){
        return;
    }
    
    //  query
    if (_subvcArrays){
        VCOtcMerchantList* vc = [_subvcArrays safeObjectAtIndex:tag - 1];
        if (vc){
            [vc queryAdList:_curr_asset_name];
        }
    }
}

@end

@interface VCOtcMerchantList ()
{
    __weak VCBase*      _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    
    EOtcAdType          _ad_type;       //  用户买入界面（商家卖出）
    UITableViewBase*    _mainTableView;
    UILabel*            _lbEmpty;
    
    NSMutableArray*     _data_array;
}

@end

@implementation VCOtcMerchantList

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbEmpty = nil;
    _data_array = nil;
    _owner = nil;
}

- (id)initWithOwner:(VCBase*)owner ad_type:(EOtcAdType)ad_type
{
    self = [super init];
    if (self) {
        // Custom initialization
        _ad_type = ad_type;
        _owner = owner;
        _data_array = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    // Do any additional setup after loading the view.
    CGRect rect = [self rectWithoutNaviAndPageBar];
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    [self.view addSubview:_mainTableView];

    //  TODO:2.9
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有任何商家在线。"];
//    _lbEmpty.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_lbEmpty];
}

- (void)queryAdList:(NSString*)asset_name
{
    //  TODO:2.9
    //    [[[OtcManager sharedOtcManager] queryIdVerify:@"say007"] then:^id(id data) {
    //        NSLog(@"%@", data);
    //        return nil;
    //    }];

    //  TODO:2.9 page
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[OtcManager sharedOtcManager] queryAdList:_ad_type asset_name:asset_name page:0 page_size:50] then:^id(id data) {
        [_owner hideBlockView];
        [self onQueryAdListResponsed:data];
        return nil;
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [[OtcManager sharedOtcManager] showOtcError:error];
        return nil;
    }];
}

- (void)onQueryAdListResponsed:(id)responsed
{
    //  TODO:2.9 这里显示异常？
    assert([[responsed objectForKey:@"code"] integerValue] == 0);
    
    id list = [[responsed objectForKey:@"data"] objectForKey:@"records"];
    [_data_array removeAllObjects];
    if (list && [list isKindOfClass:[NSArray class]]) {
        [_data_array addObjectsFromArray:list];
    }
    
    //  动态设置UI的可见性
    if ([_data_array count] > 0){
        _mainTableView.hidden = NO;
        _lbEmpty.hidden = YES;
        [_mainTableView reloadData];
    }else{
        _mainTableView.hidden = YES;
        _lbEmpty.hidden = NO;
    }
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_data_array count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8 + 24 + 4 + 20 * 2 + 40 + 8;
    
    return baseHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 8.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 8.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_merchant_cell";
    ViewOtcMerchantInfoCell* cell = (ViewOtcMerchantInfoCell*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewOtcMerchantInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor clearColor];
    }
    cell.showCustomBottomLine = YES;
    cell.adType = _ad_type;
    [cell setTagData:indexPath.row];
    [cell setItem:[_data_array objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        id item = [_data_array objectAtIndex:indexPath.row];
        assert(item);
        //  TODO:2.9 onclicked
    }];
}

/*
 *  事件 - 点击购买or出售按钮。
 */
- (void)onButtonBuyOrSellClicked:(UIButton*)sender
{
    assert(sender.tag < [_data_array count]);
    id item = [_data_array objectAtIndex:sender.tag];
    assert(item);
    //  TODO:2.9
//    [OrgUtils makeToast:_userbuy ? @"买" : @"卖"];
    
    //  TODO:2.9 
    [[MyPopviewManager sharedMyPopviewManager] showOtcTradeView:_owner ad_info:item];
}

@end

