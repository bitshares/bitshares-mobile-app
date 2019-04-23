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
#import "UIDevice+Helper.h"
#import "OrgUtils.h"

enum
{
    kSetting_language = 0,      //  多语言
    kSetting_estimate_unit,     //  记账单位
    kSetting_theme,             //  主题风格
    
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
                  @"setting_language",  //  语言
                  @"setting_currency",  //  计价方式
                  @"setting_theme",     //  主题风格
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
//    //  REMARK：section信息保存在 tag 的低字节里。
//    NSInteger section = pSwitch.tag & 0xff;
//
//
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
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    id item = [_dataArray objectAtIndex:section];
    if ([self needShowFooter:item]){
        return 26.0f;
    }
    return tableView.sectionFooterHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
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
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
            break;
        case kSetting_estimate_unit:
        {
            NSString* assetSymbol = [[SettingManager sharedSettingManager] getEstimateAssetSymbol];
            id currency = [[ChainObjectManager sharedChainObjectManager] getEstimateUnitBySymbol:assetSymbol];
            assert(currency);
            cell.detailTextLabel.text = NSLocalizedString([currency objectForKey:@"namekey"], @"计价单位名称");
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
            break;
        case kSetting_theme:
        {
            NSString* themeCode = [[[SettingManager sharedSettingManager] getThemeInfo] objectForKey:@"themeCode"];
            cell.detailTextLabel.text = [[ThemeManager sharedThemeManager] getThemeNameFromThemeCode:themeCode];
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
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
            default:
                break;
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
    [self refreshBackButtonText];
    self.title = NSLocalizedString(@"kVcTitleSetting", @"设置");
    if (_mainTableView) {
        [_mainTableView reloadData];
    }
}

@end
