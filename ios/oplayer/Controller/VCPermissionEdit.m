//
//  VCPermissionEdit.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCPermissionEdit.h"
#import "ViewPermissionInfoCellB.h"
#import "VCPermissionAddOne.h"

enum
{
    kVcSecBaseInfo = 0,     //  阈值等基本信息
    kVcSecAuthorityList,    //  权利实体列表
    kVcSecBtnAddOne,        //  添加
    kVcSecBtnSubmit,        //  提交
    
    kVcSecMax
};

@interface VCPermissionEdit ()
{
    NSInteger               _maximum_authority_membership;  //  最大多签成员数量（理事会控制）
    
    NSInteger               _weightThreshold;
    NSMutableArray*         _permissionList;
    
    UITableViewBase*        _mainTableView;
    
    ViewBlockLabel*         _lbAddOne;
    ViewBlockLabel*         _lbCommit;
}

@end

@implementation VCPermissionEdit

-(void)dealloc
{
    _permissionList = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbAddOne = nil;
    _lbCommit = nil;
}

/**
 *  (private) 排序
 */
- (void)_sort_permission_list
{
    //  根据权重降序排列
    [_permissionList sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSInteger threshold01 = [[obj1 objectForKey:@"threshold"] integerValue];
        NSInteger threshold02 = [[obj2 objectForKey:@"threshold"] integerValue];
        return threshold02 - threshold01;
    })];
}

- (id)initWithPermissionJson:(id)permission maximum_authority_membership:(NSInteger)maximum_authority_membership
{
    self = [super init];
    if (self) {
        _maximum_authority_membership = maximum_authority_membership;
        assert(permission);
        _weightThreshold = [[permission objectForKey:@"weight_threshold"] integerValue];
        _permissionList = [NSMutableArray array];
        for (id item in [permission objectForKey:@"account_auths"]) {
            assert([item count] == 2);
            [_permissionList addObject:@{@"key":[item firstObject], @"threshold":[item lastObject], @"isaccount":@YES}];
        }
        for (id item in [permission objectForKey:@"key_auths"]) {
            assert([item count] == 2);
            [_permissionList addObject:@{@"key":[item firstObject], @"threshold":[item lastObject], @"iskey":@YES}];
        }
        for (id item in [permission objectForKey:@"address_auths"]) {
            assert([item count] == 2);
            [_permissionList addObject:@{@"key":[item firstObject], @"threshold":[item lastObject], @"isaddr":@YES}];
        }
        //  根据权重降序排列
        [self _sort_permission_list];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    _lbAddOne = [self createCellLableButton:NSLocalizedString(@"kVcPermissionEditBtnAddOne", @"新增")];
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kVcPermissionEditBtnSubmit", @"提交")];
    UIColor* backColor = [ThemeManager sharedThemeManager].textColorGray;
    _lbAddOne.layer.borderColor = backColor.CGColor;
    _lbAddOne.layer.backgroundColor = backColor.CGColor;
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecBaseInfo) {
        return 2;
    } else if (section == kVcSecAuthorityList) {
        //  title + authority rows
        return [_permissionList count] + 1;
    } else {
        return 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcSecBaseInfo) {
        return tableView.rowHeight;
    } else if (indexPath.section == kVcSecAuthorityList) {
        if (indexPath.row == 0) {
            return 28.0f;   //  title
        } else {
            return 32.0f;
        }
    } else {
        return tableView.rowHeight;
    }
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
    //  TODO:2.8 多语言
    switch (indexPath.section) {
        case kVcSecBaseInfo:
        {
            if (indexPath.row == 0) {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kVcPermissionEditCellType", @"类型");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.detailTextLabel.text = @"资金权限";
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.showCustomBottomLine = YES;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            } else {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.textLabel.text = NSLocalizedString(@"kVcPermissionEditCellThreshold", @"阈值");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", @(_weightThreshold)];
                if (_weightThreshold == 0 || _weightThreshold > [self _calcAuthorityListTotalThreshold]) {
                    //  门槛阈值太高：无效
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].sellColor;
                } else {
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
                }
                cell.showCustomBottomLine = YES;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            }
        }
            break;
        case kVcSecAuthorityList:
        {
            static NSString* identify = @"id_user_permission_with_remove";
            ViewPermissionInfoCellB* cell = (ViewPermissionInfoCellB*)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                cell = [[ViewPermissionInfoCellB alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            cell.showCustomBottomLine = NO;
            cell.passThreshold = _weightThreshold;
            [cell setTagData:indexPath.row];
            if (indexPath.row == 0) {
                [cell setItem:@{@"title":@YES}];
            } else {
                [cell setItem:[_permissionList objectAtIndex:indexPath.row - 1]];
            }
            return cell;
        }
            break;
        case kVcSecBtnAddOne:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbAddOne cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;

        }
            break;
        case kVcSecBtnSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;

        }
            break;
        default:
            break;
    }
    assert(false);
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcSecBtnAddOne){
            [self onAddOneClicked];
        } else if (indexPath.section == kVcSecBtnSubmit) {
            [self onSubmitClicked];
        } else if (indexPath.section == kVcSecBaseInfo && indexPath.row == 1) {
            [self onPassThresholdClicked];
        }
    }];
}

/**
 *  (private) 计算当前设置的所有权力实体的总阈值
 */
- (NSInteger)_calcAuthorityListTotalThreshold
{
    NSInteger total_threshold = 0;
    for (id item in _permissionList) {
        total_threshold += [[item objectForKey:@"threshold"] integerValue];
    }
    return total_threshold;
}

/**
 *  事件 - 移除某个权力实体
 */
- (void)onButtonClicked_Remove:(UIButton*)button
{
    [_permissionList removeObjectAtIndex:button.tag - 1];
    [_mainTableView reloadData];
//    id item = [_dataArray objectAtIndex:button.tag];
//    if ([[item objectForKey:@"is_memo"] boolValue]) {
//    [OrgUtils showMessage:[NSString stringWithFormat:@"remove:%@", @(button.tag)]];
//        return;
//    } else {
//        //  TODO:多语言
//        VCPermissionEdit* vc = [[VCPermissionEdit alloc] initWithPermissionJson:[item objectForKey:@"raw"]];
//        [_owner pushViewController:vc
//                           vctitle:@"修改权限"
//                         backtitle:kVcDefaultBackTitleName];
//    }
}

- (void)onAddOneClicked
{
    //  限制最大多签成员数
    if ([_permissionList count] >= _maximum_authority_membership) {
       [OrgUtils makeToast:[NSString stringWithFormat:@"最多只能添加 %@ 个多签管理者。", @(_maximum_authority_membership)]];
        return;
    }

    //  REMARK：在主线程调用，否则VC弹出可能存在卡顿缓慢的情况。
    [self delay:^{
        // 转到提案确认界面
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCPermissionAddOne* vc = [[VCPermissionAddOne alloc] initWithResultPromise:result_promise];
        [self pushViewController:vc
                         vctitle:@"添加管理者"
                       backtitle:kVcDefaultBackTitleName];
        [result_promise then:(^id(id json_data) {
            //  @{@"key":key, @"name":name, @"isaccount":@(isaccount), @"threshold":@(threshold)}
            assert(json_data);
            id key = [json_data objectForKey:@"key"];
            assert(key);
            //  移除（重复的）
            for (id item in _permissionList) {
                if ([[item objectForKey:@"key"] isEqualToString:key]) {
                    [_permissionList removeObject:item];
                    break;
                }
            }
            //  添加
            [_permissionList addObject:json_data];
            //  根据权重降序排列
            [self _sort_permission_list];
            //  刷新
            [_mainTableView reloadData];
            return nil;
        })];
    }];
}

- (void)onSubmitClicked
{
    //  TODO:2.8
}

- (void)onPassThresholdClicked
{
    //  TODO:
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:@"新阈值"
                                                      withTitle:nil
                                                    placeholder:@"请输入新的阈值"
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                     completion:^(NSInteger buttonIndex, NSString *tfvalue) {
                                                         if (buttonIndex != 0){
                                                             // TODO:
                                                             _weightThreshold = [tfvalue integerValue];
                                                             [_mainTableView reloadData];
                                                         }
                                                     }];
}

@end
