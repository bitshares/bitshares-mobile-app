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
#import "VCCallOrderRanking.h"
#import "VCFeedPriceDetail.h"
#import "VCBtsaiWebView.h"
#import "VCTransfer.h"
#import "VCAdvancedFeatures.h"
#import "VCVote.h"
#import "VCDepositWithdrawList.h"

#import "WalletManager.h"
#import "OrgUtils.h"

enum
{
    kVcSubQrScan = 0,       //  扫一扫
    
    kVcSubTransfer,         //  转账
    kVcSubVote,             //  投票
    
    kVcSubAccountQuery,     //  帐号查询
    kVcSubCallRanking,      //  抵押排行
    kVcSubFeedPriceDetail,  //  喂价详情
    
    kVcSubDepositWithdraw,  //  充币&提币
    
    kVcSubAdvanced,         //  更多高级功能(HTLC等）
};

@interface VCServices ()
{    
    UITableView*            _mainTableView;
    NSArray*                _dataArray; //  assgin
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

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化数据
    _dataArray = [[[NSMutableArray array] ruby_apply:(^(id ary) {
        NSArray* pSection1 = [NSArray arrayWithObjects:
                              @[@(kVcSubTransfer),          @"kServicesCellLabelTransfer"],         //  转账
                              @[@(kVcSubVote),              @"kServicesCellLabelVoting"],           //  投票
                              nil];
        if ([pSection1 count] > 0) {
            [ary addObject:pSection1];
        }
        
        NSArray* pSection2 = @[
                               @[@(kVcSubQrScan), @"kServicesCellLabelQrScan"]                      //  扫一扫
                               ];
        if ([pSection2 count] > 0) {
            [ary addObject:pSection2];
        }
        
        NSArray* pSection3 = [[[NSMutableArray array] ruby_apply:(^(id obj) {
            [obj addObject:@[@(kVcSubAccountQuery),      @"kServicesCellLabelAccountSearch"]];      //  帐号查询
#if kAppModuleEnableRank
            [obj addObject:@[@(kVcSubCallRanking),       @"kServicesCellLabelRank"]];               //  抵押排行
#endif  //  kAppModuleEnableRank
#if kAppModuleEnableFeedPrice
            [obj addObject:@[@(kVcSubFeedPriceDetail),   @"kServicesCellLabelFeedPrice"]];          //  喂价详情
#endif  //  kAppModuleEnableFeedPrice
        })] copy];
        if ([pSection3 count] > 0) {
            [ary addObject:pSection3];
        }
        
        NSArray* pSection4 = [[[NSMutableArray array] ruby_apply:(^(id obj) {
#if kAppModuleEnableGateway
            [obj addObject:@[@(kVcSubDepositWithdraw),   @"kServicesCellLabelDepositWithdraw"]];    //  充币提币
#endif  //  kAppModuleEnableGateway
        })] copy];
        if ([pSection4 count] > 0) {
            [ary addObject:pSection4];
        }
        
        NSArray* pSection5 = @[
                               @[@(kVcSubAdvanced),         @"kServicesCellLabelAdvFunction"]       //  高级功能
                               ];
        if ([pSection5 count] > 0) {
            [ary addObject:pSection5];
        }
        
    })] copy];
    
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
//    [self.navigationController setNavigationBarHidden:YES animated:animated];
    //  登录后返回需要重新刷新列表
    [_mainTableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
//    [self.navigationController setNavigationBarHidden:NO animated:animated];
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
            cell.imageView.image = [UIImage templateImageNamed:@"iconQuery"];
            break;
        case kVcSubCallRanking:
            cell.imageView.image = [UIImage templateImageNamed:@"iconDebtRank"];
            break;
        case kVcSubFeedPriceDetail:
            cell.imageView.image = [UIImage templateImageNamed:@"iconFeedDetail"];
            break;
            
        case kVcSubDepositWithdraw:
            cell.imageView.image = [UIImage templateImageNamed:@"iconDepositWithdraw"];
            break;
            
        case kVcSubAdvanced:
            cell.imageView.image = [UIImage templateImageNamed:@"iconAdvFunction"];
            break;
        default:
            break;
    }
    
    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
    
    return cell;
    
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
                    VCQrScan* vc = [[VCQrScan alloc] init];
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
                        [VCCommonLogic viewUserAssets:self account:[account_info objectForKey:@"name"]];
                    }
                }];
                vc.title = NSLocalizedString(@"kVcTitleAccountSearch", @"帐号查询");
                break;
            }
            case kVcSubCallRanking:     //  抵押排行
            {
                vc = [[VCCallOrderRanking alloc] init];
                vc.title = NSLocalizedString(@"kVcTitleRank", @"抵押排行");
                //  TODO:page:50
                //  get_call_orders && get_full_accounts
                // TODO:其他点击
                //  vc = [[VCBtsaiWebView alloc] initWithUrl:@"http://bts.ai/a/cny"];
                //  vc.title = @"资产查询";
                break;
            }
                
            case kVcSubFeedPriceDetail: //  喂价详情
            {
                vc = [[VCFeedPriceDetail alloc] init];
                vc.title = NSLocalizedString(@"kVcTitleFeedPrice", @"喂价详情");
                break;
            }
                
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
