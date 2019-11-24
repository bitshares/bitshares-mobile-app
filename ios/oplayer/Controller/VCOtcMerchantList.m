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
#import "VCOtcUserAuthInfos.h"
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
//        return [src objectForKey:@"assetSymbol"];
//    })];
}

- (NSArray*)getSubPageVCArray
{
    return @[[[VCOtcMerchantList alloc] initWithOwner:self ad_type:eoadt_user_buy],
             [[VCOtcMerchantList alloc] initWithOwner:self ad_type:eoadt_user_sell]];
}

- (void)onRightOrderButtonClicked
{
    VCBase* vc = [[VCOtcOrders alloc] init];
    //  TODO:2.9
    [self pushViewController:vc vctitle:@"订单记录" backtitle:kVcDefaultBackTitleName];
}

- (void)onRightUserButtonClicked
{
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:nil
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:@[@"认证信息", @"收款方式"]
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
         if (buttonIndex != cancelIndex){
             // 查询用户认证信息 TODO:2.9
             OtcManager* otc = [OtcManager sharedOtcManager];
             [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
             [[[otc queryIdVerify:[otc getCurrentBtsAccount]] then:^id(id responsed) {
                 [self hideBlockView];
                 switch (buttonIndex) {
                     case 0:    //  认证信息
                     {
                         if ([otc isIdVerifyed:responsed]) {
                             VCBase* vc = [[VCOtcUserAuthInfos alloc] initWithAuthInfo:responsed[@"data"]];
                             [self pushViewController:vc vctitle:@"认证信息" backtitle:kVcDefaultBackTitleName];
                         } else {
                             VCBase* vc = [[VCOtcUserAuth alloc] init];
                             [self pushViewController:vc vctitle:@"身份认证" backtitle:kVcDefaultBackTitleName];
                         }
                     }
                         break;
                     case 1:    //  收款方式
                     {
                         if ([otc isIdVerifyed:responsed]) {
                             VCBase* vc = [[VCOtcPaymentMethods alloc] initWithAuthInfo:responsed[@"data"]];
                             [self pushViewController:vc vctitle:@"收款方式" backtitle:kVcDefaultBackTitleName];
                         } else {
                             // TODO:2.9
                             [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:@"添加收款方式之前，请先完成身份认证，是否继续？"
                                                                                    withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                                                   completion:^(NSInteger buttonIndex)
                              {
                                  if (buttonIndex == 1)
                                  {
                                      VCBase* vc = [[VCOtcUserAuth alloc] init];
                                      [self pushViewController:vc vctitle:@"身份认证" backtitle:kVcDefaultBackTitleName];
                                  }
                              }];
                         }
                     }
                         break;
                     default:
                         break;
                 }
                 return nil;
             }] catch:^id(id error) {
                 [self hideBlockView];
                 [otc showOtcError:error];
                 return nil;
             }];
         }
     }];
}

- (NSString*)genTitleString
{
    return [NSString stringWithFormat:@"%@%@", _curr_asset_name, @"市场◢"];//TODO:2.9  lang
}

- (void)onTitleAssetButtonClicked:(UIButton*)sender
{
    id list = [[OtcManager sharedOtcManager].asset_list_digital ruby_map:^id(id src) {
        return [src objectForKey:@"assetSymbol"];
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
 *  (private) 是否前往身份认证
 */
- (void)askForIdVerify:(id)responsed
{
    //  TODO:2.9
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:@"您尚未完成身份认证，不可进行场外交易，是否去认证？"
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
         if (buttonIndex == 1)
         {
//             [self gotoLogoutCore];
         }
     }];
}

/*
 *  (private) 账号异常，冻结时，是否联系客服。
 */
- (void)askForContactCustomerService:(id)responsed
{
    //  TODO:2.9
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:@"您的账号已被冻结，是否联系客服？"
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
         if (buttonIndex == 1)
         {
             // TODO:2.9
         }
     }];
}

/*
 *  (private) 价格变化，是否继续下单?
 */
- (void)askForPriceChanged:(id)ad_info lock_info:(id)lock_info
{
    //  TODO:2.9
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:@"您当前选择的订单价格有变动，是否继续下单？"
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
         if (buttonIndex == 1)
         {
             [self gotoInputOrderCore:ad_info lock_info:lock_info];
         }
     }];
}

/*
 *  (private) 前往下单
 */
- (void)gotoInputOrderCore:(id)ad_info lock_info:(id)lock_info
{
    [[[MyPopviewManager sharedMyPopviewManager] showOtcTradeView:_owner ad_info:ad_info lock_info:lock_info] then:^id(id result) {
        if (result) {
            //  输入完毕：尝试下单
            [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            OtcManager* otc = [OtcManager sharedOtcManager];
            [[[otc createUserOrder:[otc getCurrentBtsAccount]
                             ad_id:[ad_info objectForKey:@"adId"]
                              type:(EOtcAdType)[[ad_info objectForKey:@"adType"] integerValue]
                             price:[NSString stringWithFormat:@"%@", lock_info[@"unitPrice"]]
                             total:result[@"total"]] then:^id(id responsed) {
                [_owner hideBlockView];
                //  TODO:2.9
                [OrgUtils makeToast:@"order done!"];
                return nil;
            }] catch:^id(id error) {
                [_owner hideBlockView];
                [otc showOtcError:error];
                return nil;
            }];
        }
        return nil;
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
    id adId = [item objectForKey:@"adId"];
    assert(adId);
    
    OtcManager* otc = [OtcManager sharedOtcManager];
    
    //  查询用户认证信息
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[otc queryIdVerify:[otc getCurrentBtsAccount]] then:^id(id responsed) {
        //  查询认证信息
        if (![otc isIdVerifyed:responsed]) {
            [_owner hideBlockView];
            [self askForIdVerify:responsed];
            return nil;
        }
        //  查询账号状态
        if ([[[responsed objectForKey:@"data"] objectForKey:@"status"] integerValue] == eous_freeze) {
            [_owner hideBlockView];
            [self askForContactCustomerService:responsed];
            return nil;
        }
        //  TODO:2.9。付款方式是否和我的收款方式一致。
        //  前往下单（TODO:2.9 是否先查询广告详情，目前数据一直）
        return [[otc lockPrice:[otc getCurrentBtsAccount]
                         ad_id:adId
                          type:(EOtcAdType)[[item objectForKey:@"adType"] integerValue]
                  asset_symbol:[item objectForKey:@"assetSymbol"]
                         price:[item objectForKey:@"price"]] then:^id(id data) {
            [_owner hideBlockView];
            id lock_info = [data objectForKey:@"data"];
            assert(lock_info);
            NSString* oldprice = [NSString stringWithFormat:@"%@", [item objectForKey:@"price"]];
            NSString* newprice = [NSString stringWithFormat:@"%@", [lock_info objectForKey:@"unitPrice"]];
            //  价格变化
            if (![oldprice isEqualToString:newprice]) {
                [self askForPriceChanged:item lock_info:lock_info];
            } else {
                [self gotoInputOrderCore:item lock_info:lock_info];
            }
            return nil;
        }];
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

@end

