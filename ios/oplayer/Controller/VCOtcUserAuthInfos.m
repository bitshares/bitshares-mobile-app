//
//  VCOtcUserAuthInfos.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCOtcUserAuthInfos.h"
#import "OtcManager.h"

enum
{
    kVcSecName = 0,         //  名字
    kVcSecIdCardNo,         //  身份证号
    kVcSecPhoneNumber,      //  手机号
    kVcSecStauts,           //  正常 or 冻结等
    
    kVcSecMax
};

@interface VCOtcUserAuthInfos ()
{
    NSDictionary*   _auth_info;
    UITableView*    _mainTableView;
}

@end

@implementation VCOtcUserAuthInfos

- (void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _auth_info = nil;
}

- (id)initWithAuthInfo:(id)auth_info
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
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
    return kVcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
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
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    cell.showCustomBottomLine = YES;
    
    cell.textLabel.textColor = theme.textColorMain;
    cell.detailTextLabel.textColor = theme.textColorNormal;
    
    switch (indexPath.section) {
        case kVcSecName:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcRmAddCellLabelTitleName", @"姓名");
            NSString* name = [_auth_info optString:@"realName"];
            if (name && name.length >= 2) {
                name = [NSString stringWithFormat:@"*%@", [name substringFromIndex:1]];
            }
            cell.detailTextLabel.text = name ?: @"";
        }
            break;
        case kVcSecIdCardNo:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcAuthInfoCellLabelTitleIdNo", @"身份证号");
            NSString* idstr = [_auth_info optString:@"idcardNo"];
            if (idstr && idstr.length == 18) {
                idstr = [NSString stringWithFormat:@"%@********%@", [idstr substringToIndex:6], [idstr substringFromIndex:14]];
            }
            cell.detailTextLabel.text = idstr ?: @"";
        }
            break;
        case kVcSecPhoneNumber:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcAuthInfoCellLabelTitleContact", @"联系方式");
            cell.detailTextLabel.text = [_auth_info optString:@"phone"] ?: @"";
        }
            break;
        case kVcSecStauts:
        {
            cell.textLabel.text = NSLocalizedString(@"kOtcAuthInfoCellLabelTitleStatus", @"状态");
            if ([[_auth_info objectForKey:@"status"] integerValue] == eous_freeze) {
                cell.detailTextLabel.text = NSLocalizedString(@"kOtcAuthInfoCellLabelValueStatusFreeze", @"已冻结");
                cell.detailTextLabel.textColor = theme.sellColor;
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"kOtcAuthInfoCellLabelValueStatusOK", @"已认证");
                cell.detailTextLabel.textColor = theme.buyColor;
            }
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
}

@end
