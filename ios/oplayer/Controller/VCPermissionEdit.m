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
#import "ViewTipsInfoCell.h"

#import "VCImportAccount.h"

enum
{
    kVcSecBaseInfo = 0,     //  阈值等基本信息
    kVcSecAuthorityList,    //  权利实体列表
    kVcSecBtnAddOne,        //  添加
    kVcSecBtnSubmit,        //  提交
    
    kVcSecTips,             //  帮助说明提示
    
    kVcSecMax
};

@interface VCPermissionEdit ()
{
    NSMutableDictionary*    _old_authority_hash;            //  修改前的权限信息（KEY：key_threshold  VALUE：BOOL）
    NSInteger               _old_weightThreshold;           //  修改前的通过阈值
    
    NSDictionary*           _permission_item;
    NSInteger               _maximum_authority_membership;  //  最大多签成员数量（理事会控制）
    WsPromiseObject*        _result_promise;
    
    NSInteger               _weightThreshold;
    NSMutableArray*         _permissionList;
    
    UITableViewBase*        _mainTableView;
    
    ViewBlockLabel*         _lbAddOne;
    ViewBlockLabel*         _lbCommit;
    
    ViewTipsInfoCell*       _cellTips;
}

@end

@implementation VCPermissionEdit

-(void)dealloc
{
    _result_promise = nil;
    _cellTips = nil;
    _permission_item = nil;
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
              result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _permission_item = permission;
        _maximum_authority_membership = maximum_authority_membership;
        _result_promise = result_promise;
        assert(permission);
        id raw = [permission objectForKey:@"raw"];
        _old_authority_hash = [NSMutableDictionary dictionary];
        _old_weightThreshold = _weightThreshold = [[raw objectForKey:@"weight_threshold"] integerValue];
        _permissionList = [NSMutableArray array];
        for (id item in [raw objectForKey:@"account_auths"]) {
            assert([item count] == 2);
            id key = [item firstObject];
            id threshold = [item lastObject];
            [_old_authority_hash setObject:@YES forKey:[NSString stringWithFormat:@"%@_%@", key, threshold]];
            [_permissionList addObject:@{@"key":key, @"threshold":threshold, @"isaccount":@YES}];
        }
        for (id item in [raw objectForKey:@"key_auths"]) {
            assert([item count] == 2);
            id key = [item firstObject];
            id threshold = [item lastObject];
            [_old_authority_hash setObject:@YES forKey:[NSString stringWithFormat:@"%@_%@", key, threshold]];
            [_permissionList addObject:@{@"key":key, @"threshold":threshold, @"iskey":@YES}];
        }
        for (id item in [raw objectForKey:@"address_auths"]) {
            assert([item count] == 2);
            id key = [item firstObject];
            id threshold = [item lastObject];
            [_old_authority_hash setObject:@YES forKey:[NSString stringWithFormat:@"%@_%@", key, threshold]];
            [_permissionList addObject:@{@"key":key, @"threshold":threshold, @"isaddr":@YES}];
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
    
    //  提示
    _cellTips = [[ViewTipsInfoCell alloc] initWithText:NSLocalizedString(@"kVcPermissionEditHelpTips", @"【温馨提示】\n阈值：是使用该权限所需的最低权重值，各管理者账号/公钥的权重之和必须大于等于阈值。")];
    _cellTips.hideBottomLine = YES;
    _cellTips.hideTopLine = YES;
    _cellTips.backgroundColor = [UIColor clearColor];
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
    switch (indexPath.section) {
        case kVcSecAuthorityList:
        {
            if (indexPath.row == 0) {
                return 28.0f;   //  title
            } else {
                return 32.0f;
            }
        }
            break;
        case kVcSecTips:
            return [_cellTips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == kVcSecTips) {
        return 30.0f;
    }
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
        case kVcSecBaseInfo:
        {
            if (indexPath.row == 0) {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kVcPermissionEditCellType", @"类型");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.detailTextLabel.text = [_permission_item objectForKey:@"title"];
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
        case kVcSecTips:
            return _cellTips;
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
}

- (void)onAddOneClicked
{
    //  限制最大多签成员数
    if ([_permissionList count] >= _maximum_authority_membership) {
        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcPermissionEditTipsMaxAuthority", @"最多只能添加 %@ 个多签管理者。"), @(_maximum_authority_membership)]];
        return;
    }
    
    //  REMARK：在主线程调用，否则VC弹出可能存在卡顿缓慢的情况。
    [self delay:^{
        //  转到添加权限界面
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCPermissionAddOne* vc = [[VCPermissionAddOne alloc] initWithResultPromise:result_promise];
        [self pushViewController:vc
                         vctitle:NSLocalizedString(@"kVcTitlePermissionAddAuthority", @"添加管理者")
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

/*
 *  (private) 判断权限信息是否发生变化。
 */
- (BOOL)_isModifiyed
{
    //  1、判断阈值是否有修改
    if (_old_weightThreshold != _weightThreshold) {
        return YES;
    }
    
    //  2、权力实体数量发生变化（增加or减少）
    if ([_permissionList count] != [_old_authority_hash count]) {
        return YES;
    }
    
    //  3、判断权力实体以及每个实体的权重是否有修改
    for (id item in _permissionList) {
        NSString* check_key = [NSString stringWithFormat:@"%@_%@", item[@"key"], item[@"threshold"]];
        //  新KEY或新阈值在当前的权限信息中不存在，则说明已经修改。
        if (![[_old_authority_hash objectForKey:check_key] boolValue]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)onSubmitClicked
{
    //  1、检测权限信息是否变化
    if (![self _isModifiyed]) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionEditSubmitTipsNoChanged", @"权限信息没有变化。")];
        return;
    }
    
    //  2、检测阈值和权重配置是否正确。
    assert(_weightThreshold > 0);
    if (_weightThreshold > [self _calcAuthorityListTotalThreshold]) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionEditSubmitTipsInvalidPassThreshold", @"请重新调整阈值和权重配置，所有管理者账号/公钥的权重之和必须大于等于阈值。")];
        return;
    }
    
    //  3、公钥二次确认。
    id keytype_authority = [_permissionList ruby_find:(^BOOL(id src) {
        return [[src objectForKey:@"iskey"] boolValue];
    })];
    if (keytype_authority) {
        [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kVcPermissionEditSubmitSafeTipsPubkeyConfirm", @"新的管理者列表中包含公钥类型，请确认您必须持有对应的私钥。是否继续修改权限？")
                                                               withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                              completion:^(NSInteger buttonIndex)
         {
            if (buttonIndex == 1)
            {
                [self _gotoAskUpdateAccount];
            }
        }];
    } else {
        [self _gotoAskUpdateAccount];
    }
}

/**
 *  (private) 请求二次确认修改账号权限信息。
 */
- (void)_gotoAskUpdateAccount
{
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kVcPermissionEditSubmitSafeTipsSecurityConfrim", @"修改权限为高危操作，请仔细确认新管理者列表配置正确。是否继续修改权限？")
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            // 解锁钱包or账号
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked){
                    [self _submitUpdateAccountCore];
                }
            }];
        }
    }];
}

/**
 *  (private) 修改权限核心
 */
- (void)_submitUpdateAccountCore
{
    id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(account);
    id uid = account[@"id"];
    
    NSMutableArray* account_auths = [NSMutableArray array];
    NSMutableArray* key_auths = [NSMutableArray array];
    for (id item in _permissionList) {
        id key = [item objectForKey:@"key"];
        id threshold = [item objectForKey:@"threshold"];
        if ([[item objectForKey:@"isaccount"] boolValue]) {
            [account_auths addObject:@[key, threshold]];
        } else {
            [key_auths addObject:@[key, threshold]];
        }
    }
    
    id authority = @{
        @"weight_threshold":@(_weightThreshold),
        @"account_auths":[account_auths copy],
        @"key_auths":[key_auths copy],
        @"address_auths":@[],
    };
    
    EBitsharesPermissionType type = (EBitsharesPermissionType)[[_permission_item objectForKey:@"type"] integerValue];
    BOOL using_owner_authority = NO;
    
    id op_data = [NSMutableDictionary dictionary];
    op_data[@"fee"] = @{@"amount":@0, @"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID};
    op_data[@"account"] = uid;
    if (type == ebpt_owner) {
        using_owner_authority = YES;
        [op_data setObject:authority forKey:@"owner"];
    } else {
        assert(type == ebpt_active);
        using_owner_authority = NO;
        [op_data setObject:authority forKey:@"active"];
    }
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_account_update
                     using_owner_authority:using_owner_authority invoke_proposal_callback:NO
                                    opdata:op_data
                                 opaccount:account
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] accountUpdate:op_data] then:(^id(id data) {
            if ([[WalletManager sharedWalletManager] isPasswordMode]) {
                //  密码模式：修改权限之后直接退出重新登录。
                [self hideBlockView];
                //  [统计]
                [OrgUtils logEvents:@"txUpdateAccountPermissionFullOK" params:@{@"account":uid, @"mode":@"password"}];
                [[UIAlertViewManager sharedUIAlertViewManager] showMessage:NSLocalizedString(@"kVcPermissionEditSubmitOkRelogin", @"权限修改成功，请重新登录。")
                                                                 withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                                completion:^(NSInteger buttonIndex) {
                    //  注销
                    [[WalletManager sharedWalletManager] processLogout];
                    //  转到重新登录界面。
                    VCImportAccount* vc = [[VCImportAccount alloc] init];
                    [self clearPushViewController:vc
                                          vctitle:NSLocalizedString(@"kVcTitleLogin", @"登录")
                                        backtitle:kVcDefaultBackTitleName];
                }];
            } else {
                //  钱包模式：修改权限之后刷新账号信息即可。（可能当前账号不在拥有完整的active权限。）
                [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:uid] then:(^id(id full_data) {
                    [self hideBlockView];
                    //  更新账号信息
                    [[AppCacheManager sharedAppCacheManager] updateWalletAccountInfo:full_data];
                    //  [统计]
                    [OrgUtils logEvents:@"txUpdateAccountPermissionFullOK" params:@{@"account":uid, @"mode":@"wallet"}];
                    //  提示并退出
                    [[UIAlertViewManager sharedUIAlertViewManager] showMessage:NSLocalizedString(@"kVcPermissionEditSubmitOK02", @"修改权限成功。")
                                                                     withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                                    completion:^(NSInteger buttonIndex) {
                        if (_result_promise) {
                            [_result_promise resolve:full_data];
                        }
                        [self closeOrPopViewController];
                    }];
                    return nil;
                })] catch:(^id(id error) {
                    [self hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionEditSubmitOKAndRelaunchApp", @"修改权限成功，但刷新账号信息失败，请退出重新启动APP。")];
                    //  [统计]
                    [OrgUtils logEvents:@"txUpdateAccountPermissionOK" params:@{@"account":uid, @"mode":@"wallet"}];
                    return nil;
                })];
            }
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txUpdateAccountPermissionFailed" params:@{@"account":uid}];
            return nil;
        })];
    }];
}

- (void)onPassThresholdClicked
{
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kVcPermissionEditNewPassThresholdTitle", @"新阈值")
                                                      withTitle:nil
                                                    placeholder:NSLocalizedString(@"kVcPermissionEditNewPassThresholdPlaceholder", @"请输入新的阈值")
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                          tfcfg:(^(SCLTextView *tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.iDecimalPrecision = 0;
    })
                                                     completion:(^(NSInteger buttonIndex, NSString *tfvalue) {
        if (buttonIndex != 0){
            id n_threshold = [OrgUtils auxGetStringDecimalNumberValue:tfvalue];
            id n_min_threshold = [NSDecimalNumber decimalNumberWithString:@"1"];
            //  REMARK：单个 authority 的最大值是 65535，目前理事会参数最多10个 authority。这里目前配置最大范围可以容量 100+ authority。
            id n_max_threshold = [NSDecimalNumber decimalNumberWithString:@"9999999"];
            if ([n_threshold compare:n_min_threshold] < 0 || [n_threshold compare:n_max_threshold] > 0) {
                [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionEditTipsInvalidPassThreshold", @"请输入有效的阈值，范围 1 - 9999999。")];
                return;
            }
            _weightThreshold = [n_threshold integerValue];
            [_mainTableView reloadData];
        }
    })];
}

@end
