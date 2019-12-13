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
    kVcSubSubmit            //  提交按钮
};

@interface VCOtcMcAdUpdate ()
{
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
}

@end

@implementation VCOtcMcAdUpdate

-(void)dealloc
{
    _assetList = nil;
    _currBalance = nil;
    _lbCommit = nil;
    _auth_info = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail ad_info:(id)curr_ad_info
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
        _user_type = user_type;
        _merchant_detail = merchant_detail;
        if (curr_ad_info) {
            _bNewAd = NO;
            _ad_infos = [curr_ad_info mutableCopy];
        } else {
            _bNewAd = YES;
            _ad_infos = [NSMutableDictionary dictionary];
            //  TODO:2.9 init default value?
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    _dataArray = @[
        @[@(kVcSubAdType), @(kVcSubAdAsset), @(kVcSubAdFiatAsset)],
        @[@(kVcSubPriceType), @(kVcSubPriceValue)],
        @[@(kVcSubAvailable), @(kVcSubAmount)],
        @[@(kVcSubMinLimit), @(kVcSubMaxLimit)],
        @[@(kVcSubRemark)],
        @[@(kVcSubSubmit)]
    ];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  TODO:2.9
    _lbCommit = [self createCellLableButton:_bNewAd ? @"发布广告" : @"更新广告"];
    
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

- (void)_setDetailTextLabelText:(UILabel*)label value:(id)value defaultText:(NSString*)defaultText
{
    if (value) {
        label.text = [NSString stringWithFormat:@"%@", value];
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
    
    //  TODO:2.9 lang
    switch (rowType) {
        case kVcSubAdType:
        {
            cell.textLabel.text = @"广告类型";
            id adType = [_ad_infos objectForKey:@"adType"];
            if (adType) {
                if ([adType integerValue] == eoadt_merchant_buy) {
                    cell.detailTextLabel.text = @"商家购买";
                    cell.detailTextLabel.textColor = theme.buyColor;
                } else {
                    cell.detailTextLabel.text = @"商家出售";
                    cell.detailTextLabel.textColor = theme.sellColor;
                }
            } else {
                cell.detailTextLabel.text = @"请选择广告类型";
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
            cell.textLabel.text = @"数字资产";
            id assetSymbol = [_ad_infos objectForKey:@"assetSymbol"];
            if (assetSymbol) {
                cell.detailTextLabel.text = assetSymbol;
                if (_bNewAd) {
                    cell.detailTextLabel.textColor = theme.textColorMain;
                } else {
                    cell.detailTextLabel.textColor = theme.textColorNormal;
                }
            } else {
                cell.detailTextLabel.text = @"请选择数字资产";
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
            cell.textLabel.text = @"法币";
            cell.detailTextLabel.text = @"人民币";//TODO:2.9
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
            cell.textLabel.text = @"定价方式";
            cell.detailTextLabel.text = @"固定价格";
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
            cell.textLabel.text = @"您的价格";
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"price"]
                              defaultText:@"请输入您的价格"];
        }
            break;
            
        case kVcSubAmount:
        {
            cell.textLabel.text = @"交易数量";
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"quantity"]
                              defaultText:@"请输入交易数量"];
        }
            break;
        case kVcSubAvailable:
        {
            //            cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
            //            cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
            cell.textLabel.text = @"可用";
            if (_currBalance) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", _currBalance, _ad_infos[@"assetSymbol"]];
            } else {
                cell.detailTextLabel.text = @"--";
            }
            cell.detailTextLabel.textColor = theme.textColorNormal;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            //            cell.hideBottomLine = YES;
            //            cell.showCustomBottomLine = NO;
        }
            break;
            
        case kVcSubMinLimit:
        {
            cell.textLabel.text = @"最小限额";
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"lowestLimit"]
                              defaultText:@"请输入单笔最小限额"];
        }
            break;
        case kVcSubMaxLimit:
        {
            cell.textLabel.text = @"最大限额";
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"maxLimit"]
                              defaultText:@"请输入单笔最大限额"];
        }
            break;
            
        case kVcSubRemark:
        {
            cell.textLabel.text = @"交易说明";
            [self _setDetailTextLabelText:cell.detailTextLabel value:[_ad_infos objectForKey:@"remark"]
                              defaultText:@"(选填)"];
        }
            break;
        case kVcSubSubmit:
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
        //  TODO:2.9
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
                break;
                
            case kVcSubAmount:
                break;
            case kVcSubAvailable:
                break;
                
            case kVcSubMinLimit:
                break;
            case kVcSubMaxLimit:
                break;
                
            case kVcSubRemark:
                break;
            case kVcSubSubmit:
                break;
            default:
                break;
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
    id nameList = @[@"商家购买", @"商家出售"];
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
                //  TODO:2.9 切换了广告类型，清空相关输入框数据？
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
                                                       message:@"请选择数字资产"
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
                    //  TODO:2.9 切换了广告类型，清空相关输入框数据？
                    [self refreshView];
                }];
            }
        }
    }];
}

@end
