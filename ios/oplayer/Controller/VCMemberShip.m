//
//  VCMemberShip.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCMemberShip.h"
#import "WalletManager.h"
#import "VCBackupWallet.h"

#import "OrgUtils.h"
#import "AppCacheManager.h"

enum
{
    kVcBasicInfo = 0,           //  基本信息
    kVcCommit,                  //  升级按钮
    
    kVcMax
};

enum
{
    kVcSubID = 0,               //  帐号ID
    kVcSubAccount,              //  帐号名字
    kVcSubMemberStatus,         //  会员状态
    kVcSubMemberDesc,           //  会员返现描述
    
    kVcSubBasicInfoMax
};

@interface VCMemberShip ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableView*            _mainTableView;
    
    ViewBlockLabel*         _lbCommit;
    
    BOOL                    _bIsLifetimeMemberShip;
}

@end

@implementation VCMemberShip

- (void)dealloc
{
    _lbCommit = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _owner = nil;
}

- (id)initWithOwner:(VCBase*)owner
{
    self = [super init];
    if (self) {
        _owner = owner;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    [self _refreshMemberShipStatus];
    
	// Do any additional setup after loading the view.
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kAccountBtnUpgradeToLifetimeMember", @"升级终身会员")];
}

- (void)_refreshMemberShipStatus
{
    id account_info = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(account_info);
    if ([OrgUtils isBitsharesVIP:[account_info objectForKey:@"membership_expiration_date"]]){
        _bIsLifetimeMemberShip = YES;
    }else{
        _bIsLifetimeMemberShip = NO;
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_bIsLifetimeMemberShip){
        //  no upgrade button
        return kVcMax - 1;
    }
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcBasicInfo:
            return kVcSubBasicInfoMax;
        default:
            return 1;
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcBasicInfo && indexPath.row == kVcSubMemberDesc){
        return 24.0f;
    }
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcCommit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;

            id account_info = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
            assert(account_info);
            switch (indexPath.row) {
                case kVcSubID:
                    cell.textLabel.text = @"ID";
                    cell.detailTextLabel.text = [account_info objectForKey:@"id"];
                    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                    break;
                case kVcSubAccount:
                    cell.textLabel.text = NSLocalizedString(@"kAccLabelAccount", @"账号");
                    cell.detailTextLabel.text = [account_info objectForKey:@"name"];
                    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                    break;
                case kVcSubMemberStatus:
                {
                    cell.textLabel.text = NSLocalizedString(@"kAccountMembershipStatus", @"状态");
                    if (_bIsLifetimeMemberShip){
                        cell.detailTextLabel.text = NSLocalizedString(@"kLblMembershipLifetime", @"终身会员");
                    }else{
                        cell.detailTextLabel.text = NSLocalizedString(@"kLblMembershipBasic", @"普通会员");
                    }
                }
                    break;
                case kVcSubMemberDesc:
                    cell.showCustomBottomLine = NO;
                    if (_bIsLifetimeMemberShip){
                        cell.detailTextLabel.text = NSLocalizedString(@"kAccountUpgradeTipsMember", @"尊敬的终身会员，您已享受80%的手续费返现奖励。");
                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
                    }else{
                        cell.detailTextLabel.text = NSLocalizedString(@"kAccountUpgradeTipsNotMember", @"现在升级终身会员，立享80%手续费返现奖励。");
                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
                    }
                    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
                    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                    break;
                default:
                    break;
            }
            
            return cell;
        }
            break;
    }
    //  not reached
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        UIViewController* vc = nil;
        switch (indexPath.section)
        {
            case kVcCommit:
            {
                if (indexPath.row == 0){
                    [self gotoUpgradeToLifetimeMember];
                }
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

#pragma mark- UIActionSheetDelegate

- (void)gotoUpgradeToLifetimeMember
{
    //  TODO:1.9
    [OrgUtils makeToast:@"TODO:"];
//    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kAccTipsLogout", @"注销登录将会从设备删除帐号相关信息，请确认您已经做好备份。是否继续注销？")
//                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
//                                                          completion:^(NSInteger buttonIndex)
//     {
//         if (buttonIndex == 1)
//         {
//         }
//     }];
}

@end
