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
//    kVcQrCode = 0,          //  扫一扫区域
    kVcTransfer = 0,        //  转账区域
    kVcQuery,               //  数据查询区域（账号、抵押信息、喂价信息）
    kVcGateway,             //  网关/充提
    kVcAdvanced,            //  更多高级功能(HTLC等）
    
    kVcMax
};

enum
{
    kVcSubQrScan = 0,       //  扫一扫
};

enum
{
    kVcSubTransfer = 0,     //  转账
    kVcSubVote,             //  投票
};

enum
{
    kVcSubAccountQuery = 0, //  帐号查询
    kVcSubCallRanking,      //  抵押排行
    kVcSubFeedPriceDetail,  //  喂价详情
};

enum
{
    kVcSubDepositWithdraw = 0,  //  充币&提币
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

//    //  TODO:fowallet 多语言
//    NSArray* pSection1 = [NSArray arrayWithObjects:
//                          @"扫一扫",
//                          nil];
    
    NSArray* pSection2 = [NSArray arrayWithObjects:
                          @"kServicesCellLabelTransfer",        //  转账
                          @"kServicesCellLabelVoting",          //  投票
                          nil];
    
    NSArray* pSection3 = [NSArray arrayWithObjects:
                          @"kServicesCellLabelAccountSearch",   //  帐号查询
                          @"kServicesCellLabelRank",            //  抵押排行
                          @"kServicesCellLabelFeedPrice",       //  喂价详情
                          nil];
    
    NSArray* pSection4 = [NSArray arrayWithObjects:
                          @"kServicesCellLabelDepositWithdraw", //  充币提币
                          nil];
    
    NSArray* pSection5 = @[
                           @"kServicesCellLabelAdvFunction"     //  高级功能
                           ];
    
    _dataArray = [[NSArray alloc] initWithObjects:pSection2, pSection3, pSection4, pSection5, nil];
    
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

    id ary = [_dataArray objectAtIndex:indexPath.section];
    
    cell.backgroundColor = [UIColor clearColor];
    
    cell.showCustomBottomLine = YES;
    
    cell.textLabel.text = NSLocalizedString([ary objectAtIndex:indexPath.row], @"");
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    switch (indexPath.section) {
//        case kVcQrCode:
//        {
//            switch (indexPath.row) {
//                case kVcSubQrScan:
//                {
//                    cell.imageView.image = [UIImage templateImageNamed:@"iconScan"];
//                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
//                }
//                    break;
//                    
//                default:
//                    break;
//            }
//        }
//            break;
        case kVcTransfer:
        {
            switch (indexPath.row) {
                case kVcSubTransfer:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconTransfer"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                case kVcSubVote:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconVote"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case kVcQuery:
        {
            switch (indexPath.row) {
                case kVcSubAccountQuery:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconQuery"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                case kVcSubCallRanking:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconDebtRank"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                case kVcSubFeedPriceDetail:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconFeedDetail"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case kVcGateway:
        {
            switch (indexPath.row) {
                case kVcSubDepositWithdraw:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconDepositWithdraw"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                    
                default:
                    break;
            }
        }
            break;
        case kVcAdvanced:
        {
            cell.imageView.image = [UIImage templateImageNamed:@"iconAdvFunction"];
            cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
        }
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
        UIViewController* vc = nil;
        
        switch (indexPath.section) {
//            case kVcQrCode:
//            {
//                [[[OrgUtils authorizationForCamera] then:(^id(id data) {
//                    //  TODO:fowallet 多语言
//                    VCQrScan* vc = [[VCQrScan alloc] init];
//                    vc.title = @"扫一扫";
//                    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
//                    return nil;
//                })] catch:(^id(id error) {
//                    [OrgUtils showMessage:[error reason]];
//                    return nil;
//                })];
//            }
//                break;
            case kVcTransfer:
            {
                [self GuardWalletExist:^{
                    switch (indexPath.row) {
                        case kVcSubTransfer:    //  转账
                        {
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
                        }
                            break;
                        case kVcSubVote:        //  投票
                        {
                            VCVote* vc = [[VCVote alloc] init];
                            vc.title = NSLocalizedString(@"kVcTitleVoting", @"投票");
                            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                        }
                        default:
                            break;
                    }
                }];
            }
                break;
            case kVcQuery:
            {
                switch (indexPath.row) {
                    case kVcSubAccountQuery:
                    {
                        vc = [[VCSearchNetwork alloc] initWithSearchType:enstAccount callback:^(id account_info) {
                            if (account_info){
                                [VCCommonLogic viewUserAssets:self account:[account_info objectForKey:@"name"]];
                            }
                        }];
                        vc.title = NSLocalizedString(@"kVcTitleAccountSearch", @"帐号查询");
                    }
                        break;
                    case kVcSubCallRanking:
                    {
                        vc = [[VCCallOrderRanking alloc] init];
                        vc.title = NSLocalizedString(@"kVcTitleRank", @"抵押排行");
                        //  TODO:page:50
                        //  get_call_orders && get_full_accounts
                        // TODO:其他点击
                        //  vc = [[VCBtsaiWebView alloc] initWithUrl:@"http://bts.ai/a/cny"];
                        //  vc.title = @"资产查询";
                    }
                        break;
                    case kVcSubFeedPriceDetail:
                    {
                        vc = [[VCFeedPriceDetail alloc] init];
                        vc.title = NSLocalizedString(@"kVcTitleFeedPrice", @"喂价详情");
                    }
                        break;
                    default:
                        break;
                }
            }
                break;
            case kVcGateway:
            {
                switch (indexPath.row) {
                    case kVcSubDepositWithdraw:
                    {
                        [self GuardWalletExist:^{
                            VCDepositWithdrawList* vc = [[VCDepositWithdrawList alloc] init];
                            vc.title = NSLocalizedString(@"kVcTitleDepositWithdraw", @"冲币提币");
                            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                        }];
                    }
                        break;
                        
                    default:
                        break;
                }
            }
                break;
            case kVcAdvanced:
            {
                vc = [[VCAdvancedFeatures alloc] init];
                vc.title = NSLocalizedString(@"kVcTitleDepositAdvFunction", @"高级功能");
            }
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
