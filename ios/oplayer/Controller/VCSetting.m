//
//  VCSetting.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCSetting.h"
#import "AppCacheManager.h"

#import "LangManager.h"
#import "VCSelectLanguage.h"
#import "VCSelectTheme.h"
#import "VCSelectEstimateUnit.h"
#import "VCSelectApiNode.h"
#import "VCAbout.h"

#import "VCLaunch.h"

#import "UIDevice+Helper.h"
#import "OrgUtils.h"

enum
{
    kSetting_language = 0,      //  多语言
    kSetting_estimate_unit,     //  记账单位
    kSetting_theme,             //  主题风格
    kSetting_enableHorUI,       //  横版交易界面
    kSetting_apinode,           //  API节点
    kSetting_version,           //  版本
    kSetting_about,             //  关于
    
    kSetting_Max
};

@interface VCSetting ()
{
    UITableView*            _mainTableView;
    NSArray*                _dataArray; //  assgin
}

@end

@implementation VCSetting

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
    
    _dataArray = [[NSArray alloc] initWithObjects:
                  @"setting_language",      //  语言
                  @"setting_currency",      //  计价方式
                  @"setting_theme",         //  主题风格
                  @"setting_hor_trade_ui",  //  横版交易界面
                  @"setting_apinode",       //  API节点
                  @"setting_version",       //  版本
                  @"kLblCellAboutBtspp",    //  关于
                  nil];
    
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_mainTableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- switch

- (void)onSwitchAction:(UISwitch*)pSwitch
{
    switch (pSwitch.tag) {
        case kSetting_enableHorUI:  //  启用横版交易界面
        {
            [[SettingManager sharedSettingManager] setUseConfig:kSettingKey_EnableHorTradeUI value:pSwitch.on];
        }
            break;
        default:
            break;
    }
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
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

- (BOOL)needShowFooter:(id)obj
{
    return [obj isKindOfClass:[NSArray class]] && [obj count] > 2;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    id item = [_dataArray objectAtIndex:section];
    if ([self needShowFooter:item]){
        return [item lastObject];
    }
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    id item = [_dataArray objectAtIndex:section];
    if ([self needShowFooter:item]){
        return 26.0f;
    }
    return 10.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    cell.backgroundColor = [UIColor clearColor];
    id item = [_dataArray objectAtIndex:indexPath.section];
    cell.textLabel.text = NSLocalizedString([item isKindOfClass:[NSArray class]] ? [item objectAtIndex:indexPath.row] : item, @"");
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    cell.showCustomBottomLine = YES;
    cell.detailTextLabel.text = nil;
    
    switch (indexPath.section) {
        case kSetting_language:
        {
            cell.detailTextLabel.text = [[LangManager sharedLangManager] getCurrentLanguageName];
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        }
            break;
        case kSetting_estimate_unit:
        {
            NSString* assetSymbol = [[SettingManager sharedSettingManager] getEstimateAssetSymbol];
            id currency = [[ChainObjectManager sharedChainObjectManager] getEstimateUnitBySymbol:assetSymbol];
            assert(currency);
            cell.detailTextLabel.text = NSLocalizedString([currency objectForKey:@"namekey"], @"计价单位名称");
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        }
            break;
        case kSetting_theme:
        {
            NSString* themeCode = [[[SettingManager sharedSettingManager] getThemeInfo] objectForKey:@"themeCode"];
            cell.detailTextLabel.text = [[ThemeManager sharedThemeManager] getThemeNameFromThemeCode:themeCode];
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        }
            break;
        case kSetting_enableHorUI:
        {
            UISwitch* pSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
            pSwitch.tag = indexPath.section;
            pSwitch.on = [[SettingManager sharedSettingManager] isEnableHorTradeUI];
            [pSwitch addTarget:self action:@selector(onSwitchAction:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = pSwitch;
        }
            break;
        case kSetting_apinode:
        {
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
            //  获取显示文字
            id current_node = nil;
            id user_config = [[SettingManager sharedSettingManager] getUseConfig:kSettingKey_ApiNode];
            if (user_config) {
                current_node = [user_config objectForKey:kSettingKey_ApiNode_Current];
            }
            if (current_node) {
                NSString* namekey = [current_node objectForKey:@"namekey"];
                if (namekey && ![namekey isEqualToString:@""]) {
                    cell.detailTextLabel.text = NSLocalizedString(namekey, @"node location");
                } else {
                    cell.detailTextLabel.text = [current_node objectForKey:@"location"] ?: [current_node objectForKey:@"name"];
                }
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"kSettingApiCellValueRandom", @"自动选择");
            }
        }
            break;
        case kSetting_version:
        {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"v%@", [NativeAppDelegate appVersion]];
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        }
            break;
        case kSetting_about:
        {
            //  ...
        }
            break;
        default:
            break;
    }
    
    return cell;
}

- (BOOL)validateEmailAddr:(NSString*)email
{
    NSString* emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{1,4}";
    NSPredicate* emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:email];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kSetting_language:
            {
                VCSelectLanguage* vc = [[VCSelectLanguage alloc] init];
                vc.title = NSLocalizedString(@"kVcTitleLanguage", @"语言");
                [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kSetting_estimate_unit:
            {
                VCSelectEstimateUnit* vc = [[VCSelectEstimateUnit alloc] init];
                vc.title = NSLocalizedString(@"setting_currency", @"计价方式");
                [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kSetting_theme:
            {
                VCSelectTheme* vc = [[VCSelectTheme alloc] init];
                vc.title = NSLocalizedString(@"kVcTitleTheme", @"主题风格");
                [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kSetting_enableHorUI:
                break;
            case kSetting_apinode:
            {
                VCSelectApiNode* vc = [[VCSelectApiNode alloc] init];
                [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleApiNode", @"API节点") backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kSetting_version:
                [self onCheckVersionClicked];
                break;
            case kSetting_about:
            {
                VCAbout* vc = [[VCAbout alloc] init];
                [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleAbout", @"关于") backtitle:kVcDefaultBackTitleName];
            }
                break;
            default:
                break;
        }
    }];
}

/*
 *  (private) 点击版本字段
 */
- (void)onCheckVersionClicked
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[VCLaunch checkAppUpdate] then:^id(id pVersionConfig) {
        [self hideBlockView];
        if ([VcUtils processCheckAppVersionResponsed:pVersionConfig remind_later_callback:nil]) {
            //  ...
        } else {
            [OrgUtils makeToast:NSLocalizedString(@"kSettingVersionTipsNewest", @"当前已经是最新版本。")];
        }
        return nil;
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
    [self refreshBackButtonText];
    self.title = NSLocalizedString(@"kVcTitleSetting", @"设置");
    if (_mainTableView) {
        [_mainTableView reloadData];
    }
}

@end
