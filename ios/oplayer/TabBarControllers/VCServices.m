//
//  VCServices.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCServices.h"

#import "VCQrScan.h"
#import "VCSearchNetwork.h"
#import "VCAssetDetails.h"
#import "VCAssetInfos.h"
#import "VCBtsaiWebView.h"
#import "VCTransfer.h"
#import "VCAdvancedFeatures.h"
#import "VCVote.h"
#import "VCDepositWithdrawList.h"

#import "OtcManager.h"
#import "WalletManager.h"
#import "OrgUtils.h"

enum
{
    kVcSubQrScan = 0,       //  扫一扫
    
    kVcSubTransfer,         //  转账
    kVcSubVote,             //  投票
    
    kVcSubAccountQuery,     //  帐号查询
//    kVcSubAssetQuery,       //  资产查询 TODO:5.0
    kVcSubAssetInfos,       //  智能币详情（抵押排行、喂价数据等。）
    
    kVcOtcUser,             //  场外交易
    kVcOtcMerchant,         //  商家信息
    
    kVcSubDepositWithdraw,  //  充币&提币
    kVcSubAdvanced,         //  更多高级功能(HTLC等）
    kVcSubBtsExplorer,      //  BTS区块浏览器
};

@interface VCServices ()
{    
    UITableView*            _mainTableView;
    NSArray*                _dataArray; //  assgin
    BOOL                    _bFirstShow;
}

@end

@implementation VCServices

- (void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (void)_genDataArray
{
    NSArray* pSection1 = @[
        @[@(kVcSubTransfer),    @"kServicesCellLabelTransfer"],                                 //  转账
        @[@(kVcSubVote),        @"kServicesCellLabelVoting"],                                   //  投票
    ];
    
    NSArray* pSection2 = @[
        @[@(kVcSubQrScan),      @"kServicesCellLabelQrScan"]                                    //  扫一扫
    ];
    
    NSArray* pSection3 = [[[NSMutableArray array] ruby_apply:(^(id obj) {
        [obj addObject:@[@(kVcSubAccountQuery),     @"kServicesCellLabelAccountSearch"]];       //  帐号查询
        //  TODO:7.0 通用资产查询（目前仅支持智能币查询）
        //  [obj addObject:@[@(kVcSubAssetQuery),       @"TODO:4.0资产查询"]];//TODO:4.0 lang
        if ([[[ChainObjectManager sharedChainObjectManager] getMainSmartAssetList] count] > 0) {
            [obj addObject:@[@(kVcSubAssetInfos),   @"kServicesCellLabelSmartCoin"]];           //  智能币
        }
    })] copy];
    
    NSArray* pSection4 = [[[NSMutableArray array] ruby_apply:(^(id obj) {
        //  入口可见性判断
        //  1 - 编译时宏判断
        //  2 - 根据语言判断
        //  3 - 根据服务器配置判断
#if kAppModuleEnableOTC
        if ([NSLocalizedString(@"enableOtcEntry", @"enableOtcEntry") boolValue]) {
            id cfg = [OtcManager sharedOtcManager].server_config;
            if (cfg && [[[[cfg objectForKey:@"user"] objectForKey:@"entry"] objectForKey:@"type"] integerValue] != eoet_gone) {
                [obj addObject:@[@(kVcOtcUser),     @"kServicesCellLabelOtcUser"]];             //  场外交易
            }
            if (cfg && [[[[cfg objectForKey:@"merchant"] objectForKey:@"entry"] objectForKey:@"type"] integerValue] != eoet_gone) {
                [obj addObject:@[@(kVcOtcMerchant), @"kServicesCellLabelOtcMerchant"]];         //  商家信息
            }
        }
#endif  //  kAppModuleEnableOTC
    })] copy];
    
    NSArray* pSection5 = @[
#if kAppModuleEnableGateway
        @[@(kVcSubDepositWithdraw),     @"kServicesCellLabelDepositWithdraw"],                  //  充币提币
#endif  //  kAppModuleEnableGateway
        @[@(kVcSubAdvanced),            @"kServicesCellLabelAdvFunction"],                      //  高级功能
        @[@(kVcSubBtsExplorer),         @"kServicesCellLabelBtsExplorer"],                      //  BTS区块浏览器
    ];
    
    _dataArray = [@[pSection1, pSection2, pSection3, pSection4, pSection5] ruby_select:^BOOL(id section) {
        return [section count] > 0;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化数据
    _bFirstShow = YES;
    [self _genDataArray];
    
    //  UI - 列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNaviAndTab] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //  重新初始化需要显示的数据
    if (!_bFirstShow) {
        [self _genDataArray];
    }
    _bFirstShow = NO;
    //  登录后返回需要重新刷新列表
    [_mainTableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 15.0f;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    id item = [[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    cell.backgroundColor = [UIColor clearColor];
    
    cell.showCustomBottomLine = YES;
    
    cell.textLabel.text = NSLocalizedString([item lastObject], @"");
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    switch ([[item firstObject] integerValue]) {
        case kVcSubQrScan:
            cell.imageView.image = [UIImage templateImageNamed:@"iconScan"];
            break;
            
        case kVcSubTransfer:
            cell.imageView.image = [UIImage templateImageNamed:@"iconTransfer"];
            break;
        case kVcSubVote:
            cell.imageView.image = [UIImage templateImageNamed:@"iconVote"];
            break;
            
        case kVcSubAccountQuery:
//        case kVcSubAssetQuery:
            cell.imageView.image = [UIImage templateImageNamed:@"iconQuery"];
            break;
        case kVcSubAssetInfos:
            cell.imageView.image = [UIImage templateImageNamed:@"iconDebtRank"];//TODO:6.0 icon
            break;
            
        case kVcOtcUser:
            cell.imageView.image = [UIImage templateImageNamed:@"iconOtc"];
            break;
        case kVcOtcMerchant:
            cell.imageView.image = [UIImage templateImageNamed:@"iconOtcMerchant"];
            break;
        case kVcSubDepositWithdraw:
            cell.imageView.image = [UIImage templateImageNamed:@"iconDepositWithdraw"];
            break;
            
        case kVcSubAdvanced:
            cell.imageView.image = [UIImage templateImageNamed:@"iconAdvFunction"];
            break;
            
        case kVcSubBtsExplorer:
            cell.imageView.image = [UIImage templateImageNamed:@"iconExplorer"];
            break;
        default:
            break;
    }
    
    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
    
    return cell;
}

- (void)onViewAgreementClicked:(UIButton*)sender
{
    [[UIAlertViewManager sharedUIAlertViewManager] closeLastAlertView];
    
    //  转到用户协议界面
    [[OtcManager sharedOtcManager] gotoUrlPages:self pagename:@"agreement"];
}

/*
 *  (private) 进入场外交易界面
 */
- (void)_gotoOtcUserEntry
{
    [self GuardWalletExist:^{
        //  TODO:2.9 默认参数？
        [[OtcManager sharedOtcManager] gotoOtc:self asset_name:@"CNY" ad_type:eoadt_user_buy];
    }];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        UIViewController* vc = nil;
        
        id item = [[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        
        switch ([[item firstObject] integerValue]) {
            case kVcSubQrScan:      //  扫一扫
            {
                [[[OrgUtils authorizationForCamera] then:(^id(id data) {
                    VCQrScan* vc = [[VCQrScan alloc] initWithResultPromise:nil];
                    vc.title = NSLocalizedString(@"kVcTitleQrScan", @"扫一扫");
                    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                    return nil;
                })] catch:(^id(id error) {
                    [OrgUtils showMessage:[error reason]];
                    return nil;
                })];
                break;
            }
                
            case kVcSubTransfer:    //  转账（需要登录）
            {
                [self GuardWalletExist:^{
                    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
                    id p1 = [self get_full_account_data_and_asset_hash:[[WalletManager sharedWalletManager] getWalletAccountName]];
                    id p2 = [[ChainObjectManager sharedChainObjectManager] queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
                    [[[WsPromise all:@[p1, p2]] then:(^id(id data) {
                        [self hideBlockView];
                        id full_userdata = [data objectAtIndex:0];
                        VCTransfer* vc = [[VCTransfer alloc] initWithUserFullInfo:full_userdata defaultAsset:nil];
                        vc.title = NSLocalizedString(@"kVcTitleTransfer", @"转账");
                        [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                        return nil;
                    })] catch:(^id(id error) {
                        [self hideBlockView];
                        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
                        return nil;
                    })];
                }];
                break;
            }
                
            case kVcSubVote:        //  投票（需要登录）
            {
                [self GuardWalletExist:^{
                    VCVote* vc = [[VCVote alloc] init];
                    vc.title = NSLocalizedString(@"kVcTitleVoting", @"投票");
                    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                }];
                break;
            }
                
            case kVcSubAccountQuery:    //  账号查询
            {
                vc = [[VCSearchNetwork alloc] initWithSearchType:enstAccount callback:^(id account_info) {
                    if (account_info){
                        [VcUtils viewUserAssets:self account:[account_info objectForKey:@"name"]];
                    }
                }];
                vc.title = NSLocalizedString(@"kVcTitleAccountSearch", @"帐号查询");
                break;
            }
//            case kVcSubAssetQuery:
//            {
//                vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
//                    if (asset_info){
//                        VCAssetDetails* vc = [[VCAssetDetails alloc] initWithAssetID:[asset_info objectForKey:@"id"]
//                                                                               asset:nil
//                                                                       bitasset_data:nil
//                                                                  dynamic_asset_data:nil];
//                        //  TODO:4.0 lang
//                        [self pushViewController:vc
//                                         vctitle:[NSString stringWithFormat:@"%@ 详情", asset_info[@"symbol"]]
//                                       backtitle:kVcDefaultBackTitleName];
//                    }
//                }];
//                vc.title = @"资产查询";//TODO:4.0 lang
//            }
//                break;
            case kVcSubAssetInfos:     //  智能币
            {
                vc = [[VCAssetInfos alloc] init];
                vc.title = NSLocalizedString(@"kVcTitleSmartCoin", @"智能币");
                // TODO:其他点击
                //  vc = [[VCBtsaiWebView alloc] initWithUrl:@"http://bts.ai/a/cny"];
                //  vc.title = @"资产查询";
//                break;
            }
                break;
                
            case kVcOtcUser:            //  场外交易（需要登录）
            {
                id cfg = [OtcManager sharedOtcManager].server_config;
                assert(cfg);
                id entry = [[cfg objectForKey:@"user"] objectForKey:@"entry"];
                if ([[entry objectForKey:@"type"] integerValue] == eoet_enabled) {
                    
                    NSString* otcUserAgreementKeyName = @"kOtcUserAgreementApprovedVer";
                    NSString* approvedVer = (NSString*)[[AppCacheManager sharedAppCacheManager] getPref:otcUserAgreementKeyName];
                    if (approvedVer && ![approvedVer isEqualToString:@""]) {
                        //  已同意 TODO:3.0 暂时不处理协议更新。
                        [self _gotoOtcUserEntry];
                    } else {
                        //  未同意 弹出协议对话框
                        UIButton* btnViewAgreement = [UIButton buttonWithType:UIButtonTypeSystem];
                        btnViewAgreement.titleLabel.font = [UIFont systemFontOfSize:15.0f];
                        [btnViewAgreement setTitle:NSLocalizedString(@"kOtcEntryUserAgreementLinkName", @"《点击查看OTC用户协议》") forState:UIControlStateNormal];
                        [btnViewAgreement setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
                        btnViewAgreement.userInteractionEnabled = YES;
                        [btnViewAgreement addTarget:self
                                             action:@selector(onViewAgreementClicked:)
                                   forControlEvents:UIControlEventTouchUpInside];
                        btnViewAgreement.frame = CGRectMake(0, 0, 200, 60);
                        [[UIAlertViewManager sharedUIAlertViewManager] showMessageEx:NSLocalizedString(@"kOtcEntryUserAgreementAskMessage", @"亲爱的用户您好，如果您需要使用场外交易服务，需要仔细阅读并同意以下协议。")
                                                                           withTitle:NSLocalizedString(@"kOtcEntryUserAgreementAskTitle", @"用户须知")
                                                                        cancelButton:NSLocalizedString(@"kBtnCancel", @"取消")
                                                                        otherButtons:@[NSLocalizedString(@"kOtcEntryUserAgreementBtnOK", @"同意协议")]
                                                                          customView:btnViewAgreement
                                                                          completion:^(NSInteger buttonIndex) {
                            if (buttonIndex == 1) {
                                //  记录：同意协议
                                id value = [[cfg objectForKey:@"urls"] objectForKey:@"agreement"] ?: @"approved";
                                [[[AppCacheManager sharedAppCacheManager] setPref:otcUserAgreementKeyName value:value] saveCacheToFile];
                                //  继续处理
                                [self _gotoOtcUserEntry];
                            }
                        }];
                    }
                } else {
                    NSString* msg = [entry objectForKey:@"msg"];
                    if (!msg || [msg isEqualToString:@""]) {
                        msg = NSLocalizedString(@"kOtcEntryDisableDefaultMsg", @"系统维护中，请稍后再试。");
                    }
                    [OrgUtils makeToast:msg];
                }
            }
                break;
            case kVcOtcMerchant:        //  商家信息（需要登录）
            {
                id cfg = [OtcManager sharedOtcManager].server_config;
                assert(cfg);
                id entry = [[cfg objectForKey:@"merchant"] objectForKey:@"entry"];
                if ([[entry objectForKey:@"type"] integerValue] == eoet_enabled) {
                    [self GuardWalletExist:^{
                        [[OtcManager sharedOtcManager] gotoOtcMerchantHome:self];
                    }];
                } else {
                    NSString* msg = [entry objectForKey:@"msg"];
                    if (!msg || [msg isEqualToString:@""]) {
                        msg = NSLocalizedString(@"kOtcEntryDisableDefaultMsg", @"系统维护中，请稍后再试。");
                    }
                    [OrgUtils makeToast:msg];
                }
            }
                break;
            case kVcSubDepositWithdraw: //  充提（需要登录）
            {
                [self GuardWalletExist:^{
                    VCDepositWithdrawList* vc = [[VCDepositWithdrawList alloc] init];
                    vc.title = NSLocalizedString(@"kVcTitleDepositWithdraw", @"冲币提币");
                    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                }];
                break;
            }
                
            case kVcSubAdvanced:        //  高级功能
            {
                vc = [[VCAdvancedFeatures alloc] init];
                vc.title = NSLocalizedString(@"kVcTitleDepositAdvFunction", @"高级功能");
                break;
            }
                
            case kVcSubBtsExplorer:     //  BTS区块浏览器（bts.ai）
                [OrgUtils safariOpenURL:[NSString stringWithFormat:@"https://bts.ai?lang=%@", NSLocalizedString(@"btsaiLangKey", @"langkey")]];
                break;
            default:
                break;
        }
        if (vc){
            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        }
    }];
}

#pragma mark- switch theme
- (void)switchTheme
{
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    if (_mainTableView){
        [_mainTableView reloadData];
    }
}

#pragma mark- switch language
- (void)switchLanguage
{
    self.title = NSLocalizedString(@"kTabBarNameServices", @"服务");
    self.tabBarItem.title = NSLocalizedString(@"kTabBarNameServices", @"服务");
    if (_mainTableView) {
        [_mainTableView reloadData];
    }
}

@end
