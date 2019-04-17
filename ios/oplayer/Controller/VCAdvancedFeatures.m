//
//  VCAdvancedFeatures.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCAdvancedFeatures.h"
#import "VCHtlcTransfer.h"

#import "WalletManager.h"
#import "OrgUtils.h"

enum
{
    kVcHTLC = 0,            //  HTLC相关
    
    kVcMax
};

enum
{
    kVcSubHtlcPreimage = 0, //  通过原像创建
    kVcSubHtlcHashcode,     //  通过部署码部署
};

@interface VCAdvancedFeatures ()
{    
    UITableView*            _mainTableView;
    NSArray*                _dateArray; //  assgin
}

@end

@implementation VCAdvancedFeatures

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

    //  TODO:多语言
    NSArray* pSection1 = @[
                           @"HTLC合约（原像创建）",
                           @"HTLC合约（哈希创建）"
                           ];
    
    _dateArray = @[pSection1];
    
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
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
    return [_dateArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[_dateArray objectAtIndex:section] count];
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

    id ary = [_dateArray objectAtIndex:indexPath.section];
    
    cell.backgroundColor = [UIColor clearColor];
    
    cell.showCustomBottomLine = YES;
    
    cell.textLabel.text = NSLocalizedString([ary objectAtIndex:indexPath.row], @"");
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    switch (indexPath.section) {
        case kVcHTLC:
        {
            //  TODO:2.1 高级功能图标
            cell.imageView.image = [UIImage templateImageNamed:@"iconDepositWithdraw"];
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
            case kVcHTLC:
            {
                [self GuardWalletExist:^{
                    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
                    id p1 = [self get_full_account_data_and_asset_hash:[[WalletManager sharedWalletManager] getWalletAccountName]];
                    id p2 = [[ChainObjectManager sharedChainObjectManager] queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
                    [[[WsPromise all:@[p1, p2]] then:(^id(id data) {
                        [self hideBlockView];
                        id full_userdata = [data objectAtIndex:0];
                        VCHtlcTransfer* vc = nil;
                        //  TODO:2.1多语言
                        if (indexPath.row == kVcSubHtlcPreimage){
                            vc = [[VCHtlcTransfer alloc] initWithUserFullInfo:full_userdata mode:EDM_PREIMAGE];
                            vc.title = @"创建HTLC合约";
                        }else{
                            vc = [[VCHtlcTransfer alloc] initWithUserFullInfo:full_userdata mode:EDM_HASHCODE];
                            vc.title = @"创建HTLC合约";
                        }
                        [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                        return nil;
                    })] catch:(^id(id error) {
                        [self hideBlockView];
                        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
                        return nil;
                    })];
                }];
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

@end
