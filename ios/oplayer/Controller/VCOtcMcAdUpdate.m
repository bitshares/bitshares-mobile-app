//
//  VCOtcMcAdUpdate.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcAdUpdate.h"
#import "OtcManager.h"

enum
{
    kVcSubAdType = 0,       //  广告类型
    kVcSubAdAsset,          //  资产
    kVcSubAdFiatAsset,      //  发币
    kVcSubPriceType,        //  定价方式
    kVcSubPriceValue,       //  价格
    kVcSubAmount,           //  买卖数量
    kVcSubAvailable,        //  可用余额
    kVcSubMinLimit,         //  最小限额
    kVcSubMaxLimit,         //  最大限额
    kVcSubRemark,           //  交易说明
    kVcSubSubmit,           //  提交按钮
    kVcSubSave,             //  保存按钮
};

@interface VCOtcMcAdUpdate ()
{
    WsPromiseObject*        _result_promise;
    
    NSDictionary*           _auth_info;
    EOtcUserType            _user_type;
    NSDictionary*           _merchant_detail;
    BOOL                    _bNewAd;
    NSMutableDictionary*    _ad_infos;
    NSArray*                _assetList;         //  服务器可用的资产列表
    NSString*               _currBalance;
    
    UITableViewBase*        _mainTableView;
    NSArray*                _dataArray;
    
    ViewBlockLabel*         _lbCommit;
    ViewBlockLabel*         _lbSave;
}

@end

@implementation VCOtcMcAdUpdate

-(void)dealloc
{
    _result_promise = nil;
    _assetList = nil;
    _currBalance = nil;
    _lbCommit = nil;
    _lbSave = nil;
    _auth_info = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail ad_info:(id)curr_ad_info
        result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
        _auth_info = auth_info;
        _user_type = user_type;
        _merchant_detail = merchant_detail;
        if (curr_ad_info) {
            _bNewAd = NO;
            _ad_infos = [curr_ad_info mutableCopy];
        } else {
            _bNewAd = YES;
            _ad_infos = [NSMutableDictionary dictionary];
            //  初始化新广告的部分默认值 TODO:3.0 后期可调整
            [_ad_infos setValue:[[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"legalCurrencySymbol"]
                         forKey:@"legalCurrencySymbol"];
            [_ad_infos setValue:@(eopt_price_fixed) forKey:@"priceType"];
        }
        _assetList = nil;
        _currBalance = nil;
        _dataArray = nil;
    }
    return self;
}

- (void)onQueryAssetsAndBalanceResponsed:(id)data_array
{
    _assetList = [[data_array objectAtIndex:0] objectForKey:@"data"];
    //  兼容
    if (_assetList && ![_assetList isKindOfClass:[NSArray class]]) {
        _assetList = nil;
    }
    if (_bNewAd) {
        _currBalance = nil;
    } else {
        _currBalance = [[data_array objectAtIndex:1] objectForKey:@"data"];
    }
    [self refreshView];
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (void)onlyQueryBalance:(NSString*)assetSymbol success_callback:(void (^)())success_callback
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    WsPromise* p1 = [otc queryMerchantAssetBalance:[otc getCurrentBtsAccount]
                                        otcAccount:[_merchant_detail objectForKey:@"otcAccount"]
                                        merchantId:[_merchant_detail objectForKey:@"id"]
                                       assetSymbol:assetSymbol];
    [[p1 then:^id(id responsed) {
        [self hideBlockView];
        _currBalance = [responsed objectForKey:@"data"];
        if (success_callback) {
            success_callback();
        }
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (void)queryAssetsAndBalance
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    id p1 = [otc queryAssetList:eoat_digital];
    id p2 = _bNewAd ? [NSNull null] : [otc queryMerchantAssetBalance:[otc getCurrentBtsAccount]
                                                          otcAccount:[_merchant_detail objectForKey:@"otcAccount"]
                                                          merchantId:[_merchant_detail objectForKey:@"id"]
                                                         assetSymbol:[_ad_infos objectForKey:@"assetSymbol"]];
    [[[WsPromise all:@[p1, p2]] then:^id(id data_array) {
        [self hideBlockView];
        [self onQueryAssetsAndBalanceResponsed:data_array];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (void)onDeleteAdClicked:(UIButton*)sender
{
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kOtcMcAdTipAskDelete", @"您确认删除该广告吗？")
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                if (unlocked) {
                    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
                    OtcManager* otc = [OtcManager sharedOtcManager];
                    [[[otc merchantDeleteAd:[otc getCurrentBtsAccount] ad_id:[_ad_infos objectForKey:@"adId"]] then:^id(id data) {
                        [self hideBlockView];
                        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipDeleteOK", @"删除成功。")];
                        //  返回上一个界面并刷新
                        if (_result_promise) {
                            [_result_promise resolve:@YES];
                            _result_promise = nil;
                        }
                        [self closeOrPopViewController];
                        return nil;
                    }] catch:^id(id error) {
                        [self hideBlockView];
                        [otc showOtcError:error];
                        return nil;
                    }];
                }
            }];
        }
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  编辑的时候 - 添加删除按钮
    if (!_bNewAd) {
        [self showRightButton:NSLocalizedString(@"kOtcMcAdBtnNameDelete", @"删除") action:@selector(onDeleteAdClicked:)];
    }
    
    _dataArray = [[[NSMutableArray array] ruby_apply:^(id obj) {
        [obj addObject:@[@(kVcSubAdType), @(kVcSubAdAsset), @(kVcSubAdFiatAsset)]];
        [obj addObject:@[@(kVcSubPriceType), @(kVcSubPriceValue)]];
        [obj addObject:@[@(kVcSubAvailable), @(kVcSubAmount)]];
        [obj addObject:@[@(kVcSubMinLimit), @(kVcSubMaxLimit)]];
        [obj addObject:@[@(kVcSubRemark)]];
        [obj addObject:@[@(kVcSubSubmit)]];
        if (_bNewAd) {
            [obj addObject:@[@(kVcSubSave)]];
        }
    }] copy];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    if (_bNewAd) {
        _lbCommit = [self createCellLableButton:NSLocalizedString(@"kOtcMcAdBtnPublishAd", @"发布广告")];
        //  新建的时候增加一个保存按钮
        _lbSave = [self createCellLableButton:NSLocalizedString(@"kOtcMcAdBtnSaveAd", @"保存广告")];
        UIColor* backColor = [ThemeManager sharedThemeManager].textColorGray;
        _lbSave.layer.borderColor = backColor.CGColor;
        _lbSave.layer.backgroundColor = backColor.CGColor;
    } else {
        if ([[_ad_infos objectForKey:@"status"] integerValue] == eoads_online) {
            _lbCommit = [self createCellLableButton:NSLocalizedString(@"kOtcMcAdBtnUpdateAd", @"更新广告")];
        } else {
            _lbCommit = [self createCellLableButton:NSLocalizedString(@"kOtcMcAdBtnUpdateAndUpAd", @"更新并上架广告")];
        }
    }
    
    //  查询
    [self queryAssetsAndBalance];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[_dataArray objectAtIndex:section] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //    NSInteger rowType = [[[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] integerValue];
    //    switch (rowType) {
    //        case kVcSubAvailable:
    //            return 24.0f;
    //        default:
    //            break;
    //    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (void)_setDetailTextLabelText:(UILabel*)label value:(id)value defaultText:(NSString*)defaultText fiatPrefix:(BOOL)fiatPrefix
{
    if (value) {
        if (fiatPrefix) {
            label.text = [NSString stringWithFormat:@"%@%@", [[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"legalCurrencySymbol"], value];
        } else {
            label.text = [NSString stringWithFormat:@"%@", value];
        }
        label.textColor = [ThemeManager sharedThemeManager].textColorMain;
    } else {
        label.text = defaultText;
        label.textColor = [ThemeManager sharedThemeManager].textColorGray;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger rowType = [[[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] integerValue];
    if (rowType == kVcSubSubmit) {
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }
    
    if (rowType == kVcSubSave) {
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_lbSave cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    cell.textLabel.textColor = theme.textColorNormal;
    cell.textLabel.font = [UIFont systemFontOfSize:15.0f];
    cell.detailTextLabel.textColor = theme.textColorMain;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:15.0f];
    cell.showCustomBottomLine = YES;
    
    switch (rowType) {
        case kVcSubAdType:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellAdType", @"广告类型");
            id adType = [_ad_infos objectForKey:@"adType"];
            if (adType) {
                if ([adType integerValue] == eoadt_merchant_buy) {
                    cell.detailTextLabel.text = NSLocalizedString(@"kOtcMcAdEditCellAdTypeValueBuy", @"商家购买");
                    cell.detailTextLabel.textColor = theme.buyColor;
                } else {
                    cell.detailTextLabel.text = NSLocalizedString(@"kOtcMcAdEditCellAdTypeValueSell", @"商家出售");
                    cell.detailTextLabel.textColor = theme.sellColor;
                }
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"kOtcMcAdEditCellAdTypeValueSelectPlaceholder", @"请选择广告类型");
                cell.detailTextLabel.textColor = theme.textColorGray;
            }
            //  新建的时候才可以编辑该字段
            if (!_bNewAd) {
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
        }
            break;
        case kVcSubAdAsset:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellAsset", @"数字资产");
            id assetSymbol = [_ad_infos objectForKey:@"assetSymbol"];
            if (assetSymbol) {
                cell.detailTextLabel.text = assetSymbol;
                if (_bNewAd) {
                    cell.detailTextLabel.textColor = theme.textColorMain;
                } else {
                    cell.detailTextLabel.textColor = theme.textColorNormal;
                }
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"kOtcMcAdEditCellAssetValueSelectPlaceholder", @"请选择数字资产");
                cell.detailTextLabel.textColor = theme.textColorGray;
            }
            //  新建的时候才可以编辑该字段
            if (!_bNewAd) {
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
        }
            break;
        case kVcSubAdFiatAsset:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellFiatAsset", @"法币");
            cell.detailTextLabel.text = NSLocalizedString(@"kOtcMcAdEditCellFiatAssetValueCN", @"人民币");//TODO:3.0 暂时固定一种
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (_bNewAd) {
                cell.detailTextLabel.textColor = theme.textColorMain;
            } else {
                cell.detailTextLabel.textColor = theme.textColorNormal;
            }
        }
            break;
            
        case kVcSubPriceType:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellPriceType", @"定价方式");
            switch ([[_ad_infos objectForKey:@"priceType"] integerValue]) {
                case eopt_price_fixed:
                    cell.detailTextLabel.text = NSLocalizedString(@"kOtcMcAdEditCellPriceTypeFixed", @"固定价格");
                    break;
                default:
                    assert(false);
                    cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kOtcMcAdEditCellPriceTypeUnknown", @"未知定价方式：%@"), _ad_infos[@"priceType"]];
                    break;
            }
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (_bNewAd) {
                cell.detailTextLabel.textColor = theme.textColorMain;
            } else {
                cell.detailTextLabel.textColor = theme.textColorNormal;
            }
        }
            break;
        case kVcSubPriceValue:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellYourPrice", @"您的价格");
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"price"]
                              defaultText:NSLocalizedString(@"kOtcMcAdEditCellYourPlacePlaceholder", @"请输入您的价格")
                               fiatPrefix:YES];
        }
            break;
            
        case kVcSubAmount:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellAmount", @"交易数量");
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"quantity"]
                              defaultText:NSLocalizedString(@"kOtcMcAdEditCellAmountPlaceholder", @"请输入交易数量")
                               fiatPrefix:NO];
        }
            break;
        case kVcSubAvailable:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellAvailable", @"可用");
            if (_currBalance) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", _currBalance, _ad_infos[@"assetSymbol"]];
            } else {
                cell.detailTextLabel.text = @"--";
            }
            cell.detailTextLabel.textColor = theme.textColorNormal;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
            break;
            
        case kVcSubMinLimit:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellMinLimit", @"最小限额");
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"lowestLimit"]
                              defaultText:NSLocalizedString(@"kOtcMcAdEditCellMinLimitPlaceholder", @"请输入单笔最小限额")
                               fiatPrefix:YES];
        }
            break;
        case kVcSubMaxLimit:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellMaxLimit", @"最大限额");
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"maxLimit"]
                              defaultText:NSLocalizedString(@"kOtcMcAdEditCellMaxLimitPlaceholder", @"请输入单笔最大限额")
                               fiatPrefix:YES];
        }
            break;
            
        case kVcSubRemark:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcMcAdEditCellRemark", @"交易说明");
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"remark"]
                              defaultText:NSLocalizedString(@"kOtcMcAdEditCellRemarkPlaceholder", @"(选填)")
                               fiatPrefix:NO];
        }
            break;
        case kVcSubSubmit:
        case kVcSubSave:
            assert(false);
            break;
        default:
            break;
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        NSInteger rowType = [[[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] integerValue];
        switch (rowType) {
            case kVcSubAdType:
                [self onSelectAdType];
                break;
            case kVcSubAdAsset:
                [self onSelectAssetClicked];
                break;
            case kVcSubAdFiatAsset:
                break;
                
            case kVcSubPriceType:
                break;
            case kVcSubPriceValue:
                [self onPriceValueClicked];
                break;
                
            case kVcSubAmount:
                [self onAmountClicked];
                break;
            case kVcSubAvailable:
                break;
                
            case kVcSubMinLimit:
                [self onMinLimitClicked];
                break;
            case kVcSubMaxLimit:
                [self onMaxLimitClicked];
                break;
                
            case kVcSubRemark:
                [self onRemarkClicked];
                break;
            case kVcSubSubmit:
                [self onSubmitClicked:NO];
                break;
            case kVcSubSave:
                [self onSubmitClicked:YES];
                break;
            default:
                break;
        }
    }];
}

- (void)onSubmitClicked:(BOOL)onlySaveAd
{
    id adType = [_ad_infos objectForKey:@"adType"];
    if (!adType) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipPleaseSelectAdType", @"请选择广告类型。")];
        return;
    }
    id assetSymbol = [_ad_infos objectForKey:@"assetSymbol"];
    if (!assetSymbol) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipPleaseSelectAsset", @"请选择交易的数字资产。")];
        return;
    }
    NSDictionary* current_asset = [self _getCurrentAsset:assetSymbol];
    if (!current_asset) {
        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kOtcMcAdSelectAmountTipUnkownAsset", @"不支持数字资产 %@"), assetSymbol]];
        return;
    }
    id lowestLimit = [_ad_infos objectForKey:@"lowestLimit"];
    if (!lowestLimit) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipPleaseInputMinLimit", @"请输入单笔最小限额。")];
        return;
    }
    id maxLimit = [_ad_infos objectForKey:@"maxLimit"];
    if (!maxLimit) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipPleaseInputMaxLimit", @"请输入单笔最大限额。")];
        return;
    }
    NSDecimalNumber* n_lowestLimit = [OrgUtils auxGetStringDecimalNumberValue:[NSString stringWithFormat:@"%@", lowestLimit]];
    NSDecimalNumber* n_maxLimit = [OrgUtils auxGetStringDecimalNumberValue:[NSString stringWithFormat:@"%@", maxLimit]];
    if ([n_lowestLimit compare:n_maxLimit] >= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipErrorMaxLimit", @"最大限额必须大于最小限额。")];
        return;
    }
    if ([n_lowestLimit integerValue] % 100 != 0 || [n_maxLimit integerValue] % 100 != 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipErrorMinOrMaxLimitValue", @"交易限额应该为100的整数倍。")];
        return;
    }
    id n_price = [_ad_infos objectForKey:@"price"];
    if (n_price) {
        n_price = [OrgUtils auxGetStringDecimalNumberValue:[NSString stringWithFormat:@"%@", n_price]];
    }
    if ([n_price compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipPleaseInputPrice", @"请输入交易单价。")];
        return;
    }
    id n_quantity = [_ad_infos objectForKey:@"quantity"];
    if (n_quantity) {
        n_quantity = [OrgUtils auxGetStringDecimalNumberValue:[NSString stringWithFormat:@"%@", n_quantity]];
    }
    if ([n_quantity compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipPleaseInputAmount", @"请输入交易数量。")];
        return;
    }
    //  【商家出售】的情况需要判断余额是否足够。
    if ([adType integerValue] == eoadt_merchant_sell) {
        id n_balance = [OrgUtils auxGetStringDecimalNumberValue:[NSString stringWithFormat:@"%@", _currBalance]];
        if ([n_quantity compare:n_balance] > 0) {
            [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipBalanceNotEnough", @"可用余额不足。")];
            return;
        }
    }
    
    //  参数校验完毕开始执行操作
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            OtcManager* otc = [OtcManager sharedOtcManager];
            NSDictionary* ad_args = nil;
            if (_bNewAd) {
                ad_args = @{
                    //  @"adId": @"",
                    @"adType": adType,
                    @"assetId": current_asset[@"assetId"],
                    @"assetSymbol": _ad_infos[@"assetSymbol"],
                    @"btsAccount": [otc getCurrentBtsAccount],
                    @"legalCurrencySymbol": _ad_infos[@"legalCurrencySymbol"],
                    @"lowestLimit": [NSString stringWithFormat:@"%@", n_lowestLimit],
                    @"maxLimit": [NSString stringWithFormat:@"%@", n_maxLimit],
                    @"merchantId": _merchant_detail[@"id"],
                    @"otcBtsId": _merchant_detail[@"otcAccountId"],
                    @"price": [NSString stringWithFormat:@"%@", n_price],
                    @"priceType": _ad_infos[@"priceType"],
                    @"quantity": [NSString stringWithFormat:@"%@", n_quantity],
                    @"remark": [_ad_infos optString:@"remark"] ?: @""
                };
            } else {
                ad_args = @{
                    @"adId": _ad_infos[@"adId"],
                    @"adType": adType,
                    @"assetId": _ad_infos[@"assetId"],
                    @"assetSymbol": _ad_infos[@"assetSymbol"],
                    @"btsAccount": [otc getCurrentBtsAccount],
                    @"legalCurrencySymbol": _ad_infos[@"legalCurrencySymbol"],
                    @"lowestLimit": [NSString stringWithFormat:@"%@", n_lowestLimit],
                    @"maxLimit": [NSString stringWithFormat:@"%@", n_maxLimit],
                    @"merchantId": _ad_infos[@"merchantId"],
                    @"otcBtsId": _ad_infos[@"otcBtsId"],
                    @"price": [NSString stringWithFormat:@"%@", n_price],
                    @"priceType": _ad_infos[@"priceType"],
                    @"quantity": [NSString stringWithFormat:@"%@", n_quantity],
                    @"remark": [_ad_infos optString:@"remark"] ?: @""
                };
            }
            
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            WsPromise* p1;
            if (onlySaveAd) {
                p1 = [otc merchantCreateAd:ad_args];
            } else {
                p1 = [otc merchantUpdateAd:ad_args];
            }
            [[p1 then:^id(id data) {
                [self hideBlockView];
                if (_bNewAd) {
                    if (onlySaveAd) {
                        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipSaveOK", @"保存广告成功。")];
                    } else {
                        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipPublishOK", @"发布广告成功。")];
                    }
                } else {
                    [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipUpdateOK", @"更新广告成功。")];
                }
                //  返回上一个界面并刷新
                if (_result_promise) {
                    [_result_promise resolve:@YES];
                    _result_promise = nil;
                }
                [self closeOrPopViewController];
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                [otc showOtcError:error];
                return nil;
            }];
            
        }
    }];
}

/*
 *  (private) 选择广告类型
 */
- (void)onSelectAdType
{
    if (!_bNewAd) {
        return;
    }
    id adTypeList = @[@(eoadt_merchant_buy), @(eoadt_merchant_sell)];
    id nameList = @[NSLocalizedString(@"kOtcMcAdEditCellAdTypeValueBuy", @"商家购买"),
                    NSLocalizedString(@"kOtcMcAdEditCellAdTypeValueSell", @"商家出售")];
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:nil
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:nameList
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            id select_ad_type = [adTypeList objectAtIndex:buttonIndex];
            id current_ad_type = [_ad_infos objectForKey:@"adType"];
            if (!current_ad_type || [current_ad_type integerValue] != [select_ad_type integerValue]) {
                current_ad_type = select_ad_type;
                [_ad_infos setObject:current_ad_type forKey:@"adType"];
                [self refreshView];
            }
        }
    }];
}

/*
 *  (private) 选择数字资产
 */
- (void)onSelectAssetClicked
{
    if (!_bNewAd || !_assetList) {
        return;
    }
    id list = [_assetList ruby_map:^id(id src) {
        return [src objectForKey:@"assetSymbol"];
    }];
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:NSLocalizedString(@"kOtcMcAdTipAskSelectAsset", @"请选择数字资产")
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:list
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            id select_asset_symbol = [list objectAtIndex:buttonIndex];
            NSString* current_asset_symbol = [_ad_infos objectForKey:@"assetSymbol"];
            if (!current_asset_symbol || ![current_asset_symbol isEqualToString:select_asset_symbol]) {
                current_asset_symbol = select_asset_symbol;
                [self onlyQueryBalance:current_asset_symbol success_callback:^{
                    [_ad_infos setObject:current_asset_symbol forKey:@"assetSymbol"];
                    
                    //  REMARK：切换数字资产的时候清空价格和交易数量。
                    [_ad_infos removeObjectForKey:@"price"];
                    [_ad_infos removeObjectForKey:@"quantity"];
                    
                    [self refreshView];
                }];
            }
        }
    }];
}

- (void)onPriceValueClicked
{
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kOtcMcAdTipAskInputYourPriceTitle", @"您的价格")
                                                      withTitle:nil
                                                    placeholder:NSLocalizedString(@"kOtcMcAdTipAskInputYourPricePlaceholder", @"请输入价格")
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                          tfcfg:(^(SCLTextView *tf) {
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.iDecimalPrecision = [[[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"assetPrecision"] integerValue];
    })
                                                     completion:(^(NSInteger buttonIndex, NSString *tfvalue) {
        if (buttonIndex != 0){
            NSDecimalNumber* n_value = [OrgUtils auxGetStringDecimalNumberValue:tfvalue];
            if ([n_value compare:[NSDecimalNumber zero]] == 0) {
                [_ad_infos removeObjectForKey:@"price"];
            } else {
                [_ad_infos setObject:[NSString stringWithFormat:@"%@", n_value] forKey:@"price"];
            }
            
            [_mainTableView reloadData];
        }
    })];
}

- (NSDictionary*)_getCurrentAsset:(NSString*)assetSymbol
{
    assert(assetSymbol);
    for (id asset in _assetList) {
        if ([assetSymbol isEqualToString:[asset objectForKey:@"assetSymbol"]]) {
            return asset;
        }
    }
    return nil;
}

- (void)onAmountClicked
{
    if (!_assetList) {
        return;
    }
    
    NSString* current_asset_symbol = [_ad_infos objectForKey:@"assetSymbol"];
    if (!current_asset_symbol) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSelectAmountTipFirstSelectAsset", @"请先选择数字资产。")];
        return;
    }
    
    NSDictionary* current_asset = [self _getCurrentAsset:current_asset_symbol];
    if (!current_asset) {
        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kOtcMcAdSelectAmountTipUnkownAsset", @"不支持数字资产 %@"), current_asset_symbol]];
        return;
    }
    
    NSInteger assetPrecision = [[current_asset objectForKey:@"assetPrecision"] integerValue];
    
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kOtcMcAdTipAskInputAmountTitle", @"交易数量")
                                                      withTitle:nil
                                                    placeholder:NSLocalizedString(@"kOtcMcAdTipAskInputAmountPlaceholder", @"请输入交易数量")
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                          tfcfg:(^(SCLTextView *tf) {
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.iDecimalPrecision = assetPrecision;
    })
                                                     completion:(^(NSInteger buttonIndex, NSString *tfvalue) {
        if (buttonIndex != 0){
            NSDecimalNumber* n_value = [OrgUtils auxGetStringDecimalNumberValue:tfvalue];
            if ([n_value compare:[NSDecimalNumber zero]] == 0) {
                [_ad_infos removeObjectForKey:@"quantity"];
            } else {
                [_ad_infos setObject:[NSString stringWithFormat:@"%@", n_value] forKey:@"quantity"];
            }
            [_mainTableView reloadData];
        }
    })];
}

- (void)onMinLimitClicked
{
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kOtcMcAdTipAskInputMinLimitTitle", @"最小限额")
                                                      withTitle:nil
                                                    placeholder:NSLocalizedString(@"kOtcMcAdTipAskInputMinLimitPlaceholder", @"请输入最小限额")
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                          tfcfg:(^(SCLTextView *tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.iDecimalPrecision = 0;
    })
                                                     completion:(^(NSInteger buttonIndex, NSString *tfvalue) {
        if (buttonIndex != 0){
            NSDecimalNumber* n_value = [OrgUtils auxGetStringDecimalNumberValue:tfvalue];
            if ([n_value compare:[NSDecimalNumber zero]] == 0) {
                [_ad_infos removeObjectForKey:@"lowestLimit"];
            } else {
                [_ad_infos setObject:[NSString stringWithFormat:@"%@", n_value] forKey:@"lowestLimit"];
            }
            [_mainTableView reloadData];
        }
    })];
}

- (void)onMaxLimitClicked
{
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kOtcMcAdTipAskInputMaxLimitTitle", @"最大限额")
                                                      withTitle:nil
                                                    placeholder:NSLocalizedString(@"kOtcMcAdTipAskInputMaxLimitPlaceholder", @"请输入最大限额")
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                          tfcfg:(^(SCLTextView *tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.iDecimalPrecision = 0;
    })
                                                     completion:(^(NSInteger buttonIndex, NSString *tfvalue)
                                                                 {
        if (buttonIndex != 0){
            NSDecimalNumber* n_value = [OrgUtils auxGetStringDecimalNumberValue:tfvalue];
            if ([n_value compare:[NSDecimalNumber zero]] == 0) {
                [_ad_infos removeObjectForKey:@"maxLimit"];
            } else {
                [_ad_infos setObject:[NSString stringWithFormat:@"%@", n_value] forKey:@"maxLimit"];
            }
            [_mainTableView reloadData];
        }
    })];
}

- (void)onRemarkClicked
{
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kOtcMcAdTipAskInputRemarkTitle", @"交易说明")
                                                      withTitle:nil
                                                    placeholder:NSLocalizedString(@"kOtcMcAdTipAskInputRemarkPlaceholder", @"附加交易说明")
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                          tfcfg:nil
                                                     completion:(^(NSInteger buttonIndex, NSString *tfvalue)
                                                                 {
        if (buttonIndex != 0){
            [_ad_infos setObject:tfvalue forKey:@"remark"];
            [_mainTableView reloadData];
        }
    })];
}

@end
