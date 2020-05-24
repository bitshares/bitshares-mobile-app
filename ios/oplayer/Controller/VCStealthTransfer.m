//
//  VCStealthTransfer.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCStealthTransfer.h"

#import "VCBlindBalance.h"
#import "VCBlindAccounts.h"

#import "VCTransferToBlind.h"
#import "VCTransferFromBlind.h"
#import "VCBlindTransfer.h"

#import "OrgUtils.h"

enum
{
    kVcSubBlindAccounts = 0,    //  隐私账户
    kVcSubBlindBalances,        //  隐私收据
    
    kVcSubTransferToBlind,      //  向隐私账户转账
    kVcSubTransferFromBlind,    //  从隐私账户转出
    kVcSubBlindTransfer,        //  隐私转账
    
    kVcMax
};

@interface VCStealthTransfer ()
{    
    UITableView*            _mainTableView;
    NSArray*                _dataArray; //  assgin
}

@end

@implementation VCStealthTransfer

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
    
    assert([[WalletManager sharedWalletManager] isWalletExist]);
    assert(![[WalletManager sharedWalletManager] isPasswordMode]);
    
    NSArray* pSection1 = @[
        @[@(kVcSubBlindAccounts), NSLocalizedString(@"kVcStEntryBlindAccounts", @"账户管理")],
        @[@(kVcSubBlindBalances), NSLocalizedString(@"kVcStEntryBlindBalances", @"我的收据")]
    ];
    
    NSArray* pSection2 = @[
        @[@(kVcSubTransferToBlind), NSLocalizedString(@"kVcStEntryTransferToBlind", @"转入隐私账户")],
        @[@(kVcSubTransferFromBlind), NSLocalizedString(@"kVcStEntryTransferFromBlind", @"隐私账户转出")],
        @[@(kVcSubBlindTransfer), NSLocalizedString(@"kVcStEntryBlindTransfer", @"隐私转账")]
    ];
    
    _dataArray = @[pSection1, pSection2];
    
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
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
    
    cell.textLabel.text = [item lastObject];
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
    
    switch ([[item firstObject] integerValue]) {
        case kVcSubBlindAccounts:
            cell.imageView.image = [UIImage templateImageNamed:@"iconOtcUser"];
            break;
        case kVcSubBlindBalances:
            cell.imageView.image = [UIImage templateImageNamed:@"iconProposal"];
            break;
        case kVcSubTransferToBlind:
            cell.imageView.image = [UIImage templateImageNamed:@"iconBlindTo"];
            break;
        case kVcSubTransferFromBlind:
            cell.imageView.image = [UIImage templateImageNamed:@"iconBlindFrom"];
            break;
        case kVcSubBlindTransfer:
            cell.imageView.image = [UIImage templateImageNamed:@"iconBlindTransfer"];
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
        
        id item = [[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        
        switch ([[item firstObject] integerValue]) {
            case kVcSubBlindAccounts:
            {
                [self pushViewController:[[VCBlindAccounts alloc] initWithResultPromise:nil]
                                 vctitle:NSLocalizedString(@"kVcTitleBlindAccountsMgr", @"账户管理")
                               backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kVcSubBlindBalances:
            {
                [self pushViewController:[[VCBlindBalance alloc] init]
                                 vctitle:NSLocalizedString(@"kVcTitleBlindBalancesMgr", @"我的收据")
                               backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kVcSubTransferToBlind:
            {
                //  REMARK：默认隐私转账资产为 CORE 资产。
                ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
                id core_asset_id = chainMgr.grapheneCoreAssetID;
                id p1 = [self get_full_account_data_and_asset_hash:[[WalletManager sharedWalletManager] getWalletAccountName]];
                id p2 = [chainMgr queryAllGrapheneObjects:@[core_asset_id]];
                [VcUtils simpleRequest:self
                               request:[WsPromise all:@[p1, p2]]
                              callback:^(id data_array) {
                    id full_userdata = [data_array objectAtIndex:0];
                    id core = [chainMgr getChainObjectByID:core_asset_id];
                    VCTransferToBlind* vc = [[VCTransferToBlind alloc] initWithCurrAsset:core full_account_data:full_userdata];
                    [self pushViewController:vc
                                     vctitle:NSLocalizedString(@"kVcTitleTransferToBlind", @"转入隐私账户")
                                   backtitle:kVcDefaultBackTitleName];
                }];
            }
                break;
            case kVcSubTransferFromBlind:
            {
                VCTransferFromBlind* vc = [[VCTransferFromBlind alloc] initWithBlindBalance:nil];
                [self pushViewController:vc
                                 vctitle:NSLocalizedString(@"kVcTitleTransferFromBlind", @"隐私账户转出")
                               backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kVcSubBlindTransfer:
            {
                VCBlindTransfer* vc = [[VCBlindTransfer alloc] initWithBlindBalance:nil result_promise:nil];
                [self pushViewController:vc
                                 vctitle:NSLocalizedString(@"kVcTitleBlindTransfer", @"隐私转账")
                               backtitle:kVcDefaultBackTitleName];
            }
                break;
            default:
                break;
        }
        
        
    }];
}

@end
