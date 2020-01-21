//
//  VCScanAccountName.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCScanAccountName.h"
#import "VCTransfer.h"

enum
{
    kVcSectionBase = 0,
    kVcSectionBtnTransfer,
    kVcSectionBtnAccountDetail,
    
    kVcMax
};

@interface VCScanAccountName ()
{
    NSDictionary*           _accountData;
    
    UITableViewBase*        _mainTableView;
    
    ViewBlockLabel*         _lbGotoTransfer;
    ViewBlockLabel*         _lbViewDetail;
}

@end

@implementation VCScanAccountName

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbViewDetail = nil;
    _lbGotoTransfer = nil;
}

- (id)initWithAccountData:(NSDictionary*)accountData
{
    self = [super init];
    if (self) {
        _accountData = accountData;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;

    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    _lbGotoTransfer = [self createCellLableButton:NSLocalizedString(@"kVcScanResultAccountBtnTransfer", @"转账")];
    _lbViewDetail = [self createCellLableButton:NSLocalizedString(@"kVcScanResultAccountBtnViewDetail", @"查看详情")];
    UIColor* backColor = [ThemeManager sharedThemeManager].textColorGray;
    _lbViewDetail.layer.borderColor = backColor.CGColor;
    _lbViewDetail.layer.backgroundColor = backColor.CGColor;
}


/**
 *  (private) 按钮：去转账。
 */
-(void)onGotoTransfer
{
    [self GuardWalletExist:^{
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        id p1 = [self get_full_account_data_and_asset_hash:[[WalletManager sharedWalletManager] getWalletAccountName]];
        id p2 = [[ChainObjectManager sharedChainObjectManager] queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
        [[[WsPromise all:@[p1, p2]] then:(^id(id data) {
            [self hideBlockView];
            id full_userdata = [data objectAtIndex:0];
            VCTransfer* vc = [[VCTransfer alloc] initWithUserFullInfo:full_userdata defaultAsset:nil defaultTo:_accountData];
            vc.title = NSLocalizedString(@"kVcTitleTransfer", @"转账");
            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
            return nil;
        })];
    }];
}

/**
 *  (private) 按钮：查看详情。
 */
- (void)onViewDetail
{
    [VcUtils viewUserAssets:self account:[_accountData objectForKey:@"name"]];
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSectionBase)
        return 2;
    else
        return 1;
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSectionBase:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            
            if (indexPath.row == 0) {
                //  ID
                cell.textLabel.text = @"ID";
                cell.detailTextLabel.text = [_accountData objectForKey:@"id"];
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            } else {
                //  NAME
                cell.textLabel.text = NSLocalizedString(@"kAccLabelAccount", @"帐号");
                cell.detailTextLabel.text = [_accountData objectForKey:@"name"];
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
            }
            
            return cell;
        }
            break;
        case kVcSectionBtnTransfer:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbGotoTransfer cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcSectionBtnAccountDetail:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbViewDetail cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcSectionBtnTransfer){
            [self onGotoTransfer];
        } else if (indexPath.section == kVcSectionBtnAccountDetail) {
            [self onViewDetail];
        }
    }];
}


@end
