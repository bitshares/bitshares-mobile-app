//
//  VCUserCenter.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCUserCenter.h"
#import "VCMemberShip.h"
#import "WalletManager.h"
#import "VCBackupWallet.h"

#import "OrgUtils.h"
#import "AppCacheManager.h"

#import "MBProgressHUDSingleton.h"

enum
{
    kVcBasicInfo = 0,           //  基本信息
    kVcRefererInfo,             //  引荐人等信息
    kVcBackupWallet,            //  备份钱包
    kVcLogout,                  //  注销按钮
};

enum
{
    kVcSubID = 0,               //  帐号ID
    kVcSubAccount,              //  帐号名字
};

enum
{
    kVcSubReferer = 0,          //  引荐人
    kVcSubRegistrar,            //  注册人
    kVcSubLifetimeReferer,      //  终身会员引荐人
};



@interface VCUserCenterPages ()
{
}

@end

@implementation VCUserCenterPages

-(void)dealloc
{
}

- (NSArray*)getTitleStringArray
{
    return @[NSLocalizedString(@"kAccountPageBasicInfo", @"基本信息"),
             NSLocalizedString(@"kAccountPageMemberInfo", @"会员信息")];
}

- (NSArray*)getSubPageVCArray
{
    
    id vc01 = [[VCUserCenter alloc] initWithOwner:self];
    id vc02 = [[VCMemberShip alloc] initWithOwner:self];
    return @[vc01, vc02];
}

- (void)onPageChanged:(NSInteger)tag
{
    NSLog(@"onPageChanged: %@", @(tag));
    
    //  gurad
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]){
        return;
    }
    
    //  TODO:
//    //  query
//    if (_subvcArrays){
//        id vc = [_subvcArrays safeObjectAtIndex:tag - 1];
//        if (vc && [vc isKindOfClass:[VCUserCenter class]]){
//
//        }
//    }
}

@end


@interface VCUserCenter ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableView*            _mainTableView;
    NSMutableArray*         _sectionTypeArray;
    
    ViewBlockLabel*         _lbBackupWallet;
    
    ViewBlockLabel*         _lbLogout;
}

@end

@implementation VCUserCenter

- (void)dealloc
{
    if (_sectionTypeArray){
        [_sectionTypeArray removeAllObjects];
        _sectionTypeArray = nil;
    }
    _lbBackupWallet = nil;
    _lbLogout = nil;
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

- (void)buildSectionTypeArray
{
    [_sectionTypeArray removeAllObjects];

    [_sectionTypeArray addObject:@(kVcBasicInfo)];
    [_sectionTypeArray addObject:@(kVcRefererInfo)];
    if (_lbBackupWallet){
        [_sectionTypeArray addObject:@(kVcBackupWallet)];
    }
    [_sectionTypeArray addObject:@(kVcLogout)];
}

- (void)reloadView
{
    [self buildSectionTypeArray];
    [_mainTableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
	// Do any additional setup after loading the view.
    _sectionTypeArray = [[NSMutableArray alloc] init];
    
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  TODO:fowallet 暂时把钱包备份放在这里，以后添加 多帐号、钱包管理等。
    if ([[[AppCacheManager sharedAppCacheManager] getWalletInfo] objectForKey:@"kFullWalletBin"]){
        _lbBackupWallet = [self createCellLableButton:NSLocalizedString(@"kWalletBtnBackup", @"备份钱包")];
        _lbLogout = [self createCellLableButton:NSLocalizedString(@"kLogout", @"注销")];
        UIColor* backColor = [ThemeManager sharedThemeManager].textColorGray;
        _lbLogout.layer.borderColor = backColor.CGColor;
        _lbLogout.layer.backgroundColor = backColor.CGColor;
    }else{
        _lbBackupWallet = nil;
        _lbLogout = [self createCellLableButton:NSLocalizedString(@"kLogout", @"注销")];
    }

    [self reloadView];
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
    return [_sectionTypeArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch ([[_sectionTypeArray objectAtIndex:section] integerValue]) {
        case kVcBasicInfo:
            return 2;
        case kVcRefererInfo:
            return 3;
        default:
            return 1;
    }
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
    NSInteger sectionType = [[_sectionTypeArray objectAtIndex:indexPath.section] integerValue];
    switch (sectionType) {
        case kVcLogout:
        {
            //  注销
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbLogout cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcBackupWallet:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbBackupWallet cell:cell leftEdge:tableView.layoutMargins.left];
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
            switch (sectionType) {
                case kVcBasicInfo:
                {
                    id wallet_info = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    switch (indexPath.row) {
                        case kVcSubID:
                            cell.textLabel.text = @"ID";
                            cell.detailTextLabel.text = [wallet_info objectForKey:@"id"];
                            break;
                        case kVcSubAccount:
                            cell.textLabel.text = NSLocalizedString(@"kAccLabelAccount", @"帐号");
                            cell.detailTextLabel.text = [wallet_info objectForKey:@"name"];
                            break;
                        default:
                            break;
                    }
                }
                    break;
                case kVcRefererInfo:
                {
                    id account_full_info = [[WalletManager sharedWalletManager] getWalletAccountInfo];
                    switch (indexPath.row) {
                        case kVcSubReferer:
                            cell.textLabel.text = NSLocalizedString(@"kAccLabelReferrer", @"引荐人");
                            cell.detailTextLabel.text = [account_full_info objectForKey:@"referrer_name"];
                            cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                            break;
                        case kVcSubRegistrar:
                            cell.textLabel.text = NSLocalizedString(@"kAccLabelRegistrar", @"注册人");
                            cell.detailTextLabel.text = [account_full_info objectForKey:@"registrar_name"];
                            cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                            break;
                        case kVcSubLifetimeReferer:
                            cell.textLabel.text = NSLocalizedString(@"kAccLabelLifetimeRef", @"终身会员引荐人");
                            cell.detailTextLabel.text = [account_full_info objectForKey:@"lifetime_referrer_name"];
                            cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
                            break;
                        default:
                            break;
                    }
                }
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
        switch ([[_sectionTypeArray objectAtIndex:indexPath.section] integerValue])
        {
            case kVcLogout: //  注销
            {
                if (indexPath.row == 0){
                    [self gotoLogout];
                }
            }
                break;
            case kVcBackupWallet:
            {
                [self backupWallet];
            }
                break;
            default:
                break;
        }
    }];
}

#pragma mark- UIActionSheetDelegate

- (void)backupWallet
{
    VCBackupWallet* vc = [[VCBackupWallet alloc] init];
    vc.title = NSLocalizedString(@"kVcTitleBackupWallet", @"备份钱包");
    [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

- (void)gotoLogoutCore
{
    //  内存钱包锁定、导入钱包删除。
    [[WalletManager sharedWalletManager] Lock];
    [[AppCacheManager sharedAppCacheManager] removeWalletInfo];
    
    //  返回
    [_owner closeOrPopViewController];
}

- (void)gotoLogout
{
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kAccTipsLogout", @"注销登录将会从设备删除帐号相关信息，请确认您已经做好备份。是否继续注销？")
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
         if (buttonIndex == 1)
         {
             [self gotoLogoutCore];
         }
     }];
}

@end
