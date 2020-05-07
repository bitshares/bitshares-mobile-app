//
//  VCPermissionList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCPermissionList.h"
#import "ViewPermissionInfoCell.h"
#import "VCPermissionEdit.h"
#import "VCNewAccountPassword.h"

@interface VCPermissionList ()
{
    __weak VCBase*          _owner;                             //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    ViewBlockLabel*         _lbChangePasswordButton;
}

@end

@implementation VCPermissionList

-(void)dealloc
{
    _owner = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbChangePasswordButton = nil;
}

- (id)initWithOwner:(VCBase*)owner
{
    self = [super init];
    if (self) {
        _owner = owner;
    }
    return self;
}

- (void)_onQueryDependencyAccountNameResponsed
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    for (id row in _dataArray) {
        for (id item in [row objectForKey:@"items"]) {
            if ([[item objectForKey:@"isaccount"] boolValue]) {
                id oid = [item objectForKey:@"key"];
                id account = [chainMgr getChainObjectByID:oid];
                if (account) {
                    [item setObject:account[@"name"] forKey:@"name"];
                }
            }
        }
    }
    [self _refreshUI:nil];
}

/*
 *  (public) 点击权限界面TAB - 刷新当前账号信息（可能从其他地方修改了账号，比如其他APP或者提案等。）
 */
- (void)refreshCurrAccountData
{
    id curr_full_account_data = [[WalletManager sharedWalletManager] getWalletAccountInfo];
    assert(curr_full_account_data);
    id curr_account_id = [[curr_full_account_data objectForKey:@"account"] objectForKey:@"id"];
    assert(curr_account_id);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    //  查询最新账号信息 & 依赖的其他多签账号名
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[chainMgr queryFullAccountInfo:curr_account_id] then:^id(id full_data) {
        assert(full_data);
        //  [持久化] 更新当前钱包账号信息
        if (full_data) {
            [[AppCacheManager sharedAppCacheManager] updateWalletAccountInfo:full_data];
        }
        
        //  更新之后重新初始化 data_array 。
        [self _initDataArrayWithFullAccountData:full_data];
        
        //  分析依赖
        NSMutableDictionary* account_id_hash = [NSMutableDictionary dictionary];
        for (id row in _dataArray) {
            for (id item in [row objectForKey:@"items"]) {
                if ([[item objectForKey:@"isaccount"] boolValue]) {
                    [account_id_hash setObject:@YES forKey:[item objectForKey:@"key"]];
                }
            }
        }
        
        if ([account_id_hash count] <= 0) {
            //  无依赖：直接用新数据刷新列表
            [_owner hideBlockView];
            [self _refreshUI:nil];
            return nil;
        } else {
            //  查询依赖
            return [[chainMgr queryAllAccountsInfo:[account_id_hash allKeys]] then:^id(id data) {
                [_owner hideBlockView];
                [self _onQueryDependencyAccountNameResponsed];
                return nil;
            }];
        }
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

/**
 *  (private) 账号权限是否可以修改判断
 */
- (BOOL)_canBeModified:(NSDictionary*)account permission:(id)permission
{
    id oid = [account objectForKey:@"id"];
    if ([oid isEqualToString:BTS_GRAPHENE_COMMITTEE_ACCOUNT] ||
        [oid isEqualToString:BTS_GRAPHENE_WITNESS_ACCOUNT] ||
        [oid isEqualToString:BTS_GRAPHENE_TEMP_ACCOUNT] ||
        [oid isEqualToString:BTS_GRAPHENE_PROXY_TO_SELF]) {
        return NO;
    }
    return YES;
}

- (id)_parsePermissionJson:(id)permission title:(NSString*)title account:(id)account type:(EBitsharesPermissionType)type
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    assert(permission);
    BOOL canBeModified = [self _canBeModified:account permission:permission];
    //  memo key
    if ([permission isKindOfClass:[NSString class]]) {
        return @{@"title":title, @"weight_threshold":@1, @"type":@(type),
                 @"is_memo":@YES, @"items":@[@{@"key":permission, @"threshold":@1}], @"canBeModified":@(canBeModified)};
    }
    //  other permission
    NSInteger weight_threshold = [[permission objectForKey:@"weight_threshold"] integerValue];
    id account_auths = [permission objectForKey:@"account_auths"];
    id key_auths = [permission objectForKey:@"key_auths"];
    id address_auths = [permission objectForKey:@"address_auths"];
    NSMutableArray* list = [NSMutableArray array];
    BOOL onlyIncludeKeyAuthority = YES;
    NSInteger curr_threshold = 0;
    for (id item in account_auths) {
        assert([item count] == 2);
        id oid = [item firstObject];
        NSInteger threshold = [[item lastObject] integerValue];
        curr_threshold += threshold;
        id mutable_hash = [NSMutableDictionary dictionaryWithObjectsAndKeys:oid, @"key", @YES, @"isaccount", @(threshold), @"threshold", nil];
        //  查询依赖的名字
        id multi_sign_account = [chainMgr getChainObjectByID:oid searchFileCache:YES];
        if (multi_sign_account) {
            [mutable_hash setObject:multi_sign_account[@"name"] forKey:@"name"];
        }
        [list addObject:mutable_hash];
        onlyIncludeKeyAuthority = NO;
    }
    for (id item in key_auths) {
        assert([item count] == 2);
        id key = [item firstObject];
        NSInteger threshold = [[item lastObject] integerValue];
        curr_threshold += threshold;
        [list addObject:@{@"key":key, @"iskey":@YES, @"threshold":@(threshold)}];
    }
    for (id item in address_auths) {
        assert([item count] == 2);
        id addr = [item firstObject];
        NSInteger threshold = [[item lastObject] integerValue];
        curr_threshold += threshold;
        [list addObject:@{@"key":addr, @"isaddr":@YES, @"threshold":@(threshold)}];
        onlyIncludeKeyAuthority = NO;
    }
    if (curr_threshold >= weight_threshold) {
        //  根据权重降序排列
        [list sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSInteger threshold01 = [[obj1 objectForKey:@"threshold"] integerValue];
            NSInteger threshold02 = [[obj2 objectForKey:@"threshold"] integerValue];
            return threshold02 - threshold01;
        })];
        //  REMARK：仅包含一个权力实体，并且是KEY类型。不是account、address等。
        BOOL only_one_key = onlyIncludeKeyAuthority && [list count] == 1;
        return @{@"title":title, @"weight_threshold":@(weight_threshold), @"type":@(type), @"only_one_key":@(only_one_key), @"items":list, @"canBeModified":@(canBeModified), @"raw":permission};
    }
    //  no permission
    return nil;
}

/*
 *  (private) 初始化数据
 */
- (void)_initDataArrayWithFullAccountData:(id)full_account_data
{
    assert(full_account_data);
    _dataArray = [[[NSMutableArray array] ruby_apply:(^(id ary) {
        id account = [full_account_data objectForKey:@"account"];
        assert(account);
        id owner = [account objectForKey:@"owner"];
        assert(owner);
        id value = [self _parsePermissionJson:owner
                                        title:NSLocalizedString(@"kVcPermissionTypeOwner", @"账号权限")
                                      account:account
                                         type:ebpt_owner];
        if (value) {
            [ary addObject:value];
        }
        
        id active = [account objectForKey:@"active"];
        assert(active);
        value = [self _parsePermissionJson:active
                                     title:NSLocalizedString(@"kVcPermissionTypeActive", @"资金权限")
                                   account:account
                                      type:ebpt_active];
        if (value) {
            [ary addObject:value];
        }
        
        id memo_key = [[account objectForKey:@"options"] objectForKey:@"memo_key"];
        assert(memo_key);
        value = [self _parsePermissionJson:memo_key
                                     title:NSLocalizedString(@"kVcPermissionTypeMemo", @"备注权限")
                                   account:account
                                      type:ebpt_memo];
        if (value) {
            [ary addObject:value];
        }
    })] copy];
    assert([_dataArray count] > 0);
}

/*
 *  (private) 刷新界面
 *  full_account_data - 有新的账号信息则重新初始化列表，否则仅重新刷新列表。
 */
- (void)_refreshUI:(id)full_account_data
{
    if (full_account_data) {
        [self _initDataArrayWithFullAccountData:full_account_data];
    }
    [_mainTableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化数据
    [self _initDataArrayWithFullAccountData:[[WalletManager sharedWalletManager] getWalletAccountInfo]];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 修改为密码模式
    _lbChangePasswordButton = [self createCellLableButton:NSLocalizedString(@"kEditPasswordBtnEntry", @"修改密码")];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    //  各种权限 + 【修改密码】按钮
    return [_dataArray count] + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //  【修改密码】按钮高度
    if (indexPath.section >= [_dataArray count]) {
        return tableView.rowHeight;
    }
    
    id item = [_dataArray objectAtIndex:indexPath.section];
    NSInteger line_number = [[item objectForKey:@"items"] count];
    BOOL bHideThreshold = [[item objectForKey:@"is_memo"] boolValue];
    if (!bHideThreshold) {
        line_number += 1;
    }
    //  行数 + 间隔
    return line_number * 28 + 12.0f;
}

///**
// *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
// */
//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
//{
//    return 10.0f;
//}
//- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//    return @" ";
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
//{
//    return 10.0f;
//}
//- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
//{
//    return @" ";
//}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    //  【修改密码】按钮
    if (section >= [_dataArray count]) {
        return 12.0f;
    }
    return 44.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    //  【修改密码】按钮
    if (section >= [_dataArray count]) {
        return [[UIView alloc] init];
    }
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  权限类型
    CGFloat fWidth = self.view.bounds.size.width;
    CGFloat xOffset = tableView.layoutMargins.left;
    UIView* myView = [[UIView alloc] init];
    myView.backgroundColor = theme.appBackColor;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 44)];
    titleLabel.textColor = theme.textColorHighlight;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    
    id item = [_dataArray objectAtIndex:section];
    titleLabel.text = [NSString stringWithFormat:@"%@. %@", @(section + 1), item[@"title"]];
    [myView addSubview:titleLabel];
    
    //  编辑按钮
    if ([[item objectForKey:@"canBeModified"] boolValue]) {
        CGSize size1 = [ViewUtils auxSizeWithLabel:titleLabel];
        UIButton* btnModify = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage* btn_image = [UIImage templateImageNamed:@"iconEdit"];
        CGSize btn_size = btn_image.size;
        [btnModify setBackgroundImage:btn_image forState:UIControlStateNormal];
        btnModify.userInteractionEnabled = YES;
        [btnModify addTarget:self action:@selector(onButtonClicked_Modify:) forControlEvents:UIControlEventTouchUpInside];
        btnModify.frame = CGRectMake(xOffset + size1.width + 8,
                                     (44 - btn_size.height) / 2, btn_size.width, btn_size.height);
        btnModify.tintColor = theme.textColorHighlight;
        btnModify.tag = section;
        [myView addSubview:btnModify];
    }
    
    //  末尾 - 阈值
    if (![[item objectForKey:@"is_memo"] boolValue]) {
        UILabel* secLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 44)];
        secLabel.textAlignment = NSTextAlignmentRight;
        secLabel.backgroundColor = [UIColor clearColor];
        secLabel.font = [UIFont boldSystemFontOfSize:13];
        secLabel.attributedText = [ViewUtils genAndColorAttributedText:NSLocalizedString(@"kVcPermissionPassThreshold", @"阈值 ")
                                                                 value:[NSString stringWithFormat:@"%@", item[@"weight_threshold"]]
                                                            titleColor:theme.textColorNormal
                                                            valueColor:theme.textColorMain];
        [myView addSubview:secLabel];
    }
    
    return myView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section >= [_dataArray count]) {
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.hideBottomLine = YES;
        cell.hideTopLine = YES;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_lbChangePasswordButton cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }
    
    static NSString* identify = @"id_user_permission";
    ViewPermissionInfoCell* cell = (ViewPermissionInfoCell*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewPermissionInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.showCustomBottomLine = YES;
    [cell setItem:[_dataArray objectAtIndex:indexPath.section]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section >= [_dataArray count]){
            VCNewAccountPassword* vc = [[VCNewAccountPassword alloc] initWithScene:kNewPasswordSceneChangePassowrd args:nil];
            [_owner pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleEditPassword", @"修改密码") backtitle:kVcDefaultBackTitleName];
        }
    }];
}

/*
 *  (private) 处理修改备注权限
 */
- (void)_onModifyMemoKeyClicked:(id)item newKey:(NSString*)newKey
{
    if (![OrgUtils isValidBitsharesPublicKey:newKey])
    {
        [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionSubmitTipsInputValidMemoKey", @"请输入有效的公钥。")];
        return;
    }
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    id account_data = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(account_data);
    [[[ChainObjectManager sharedChainObjectManager] queryAccountData:account_data[@"id"]] then:(^id(id newestAccountData) {
        [_owner hideBlockView];
        if (newestAccountData && [newestAccountData objectForKey:@"id"] && [newestAccountData objectForKey:@"name"]) {
            id account_options = [newestAccountData objectForKey:@"options"];
            if ([[account_options objectForKey:@"memo_key"] isEqualToString:newKey]) {
                [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionSubmitTipsMemoKeyNoChanged", @"备注权限没有变化。")];
            } else {
                [_owner GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                    if (unlocked) {
                        [self _onModifyMemoKeyCore:item newKey:newKey newestAccountData:newestAccountData];
                    }
                }];
            }
        } else {
            [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        }
        return nil;
    })];
}

- (void)_onModifyMemoKeyCore:(id)item newKey:(NSString*)newKey newestAccountData:(id)account_data
{
    assert(newKey && account_data);
    
    id uid = account_data[@"id"];
    id account_options = [account_data objectForKey:@"options"];
    
    id op_data = @{
        @"fee":@{@"amount":@0, @"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID},
        @"account":uid,
        @"new_options":@{
                @"memo_key":newKey,
                @"voting_account":[account_options objectForKey:@"voting_account"],
                @"num_witness":[account_options objectForKey:@"num_witness"],
                @"num_committee":[account_options objectForKey:@"num_committee"],
                @"votes":[account_options objectForKey:@"votes"]
        },
    };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [_owner GuardProposalOrNormalTransaction:ebo_account_update
                       using_owner_authority:NO invoke_proposal_callback:NO
                                      opdata:op_data
                                   opaccount:account_data
                                        body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] accountUpdate:op_data] then:(^id(id data) {
            [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:uid] then:(^id(id full_data) {
                [_owner hideBlockView];
                //  刷新
                [self _refreshUI:full_data];
                [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionSubmitModifyMemoKeyFullOK", @"修改备注权限成功。")];
                //  [统计]
                [OrgUtils logEvents:@"txUpdateMemoKeyPermissionFullOK" params:@{@"account":uid}];
                return nil;
            })] catch:(^id(id error) {
                [_owner hideBlockView];
                [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionSubmitModifyMemoKeyOK", @"修改备注权限成功，但刷新界面数据失败，请稍后再试。")];
                //  [统计]
                [OrgUtils logEvents:@"txUpdateMemoKeyPermissionOK" params:@{@"account":uid}];
                return nil;
            })];
            return nil;
        })] catch:(^id(id error) {
            [_owner hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txUpdateMemoKeyPermissionFailed" params:@{@"account":uid}];
            return nil;
        })];
    }];
}

/**
 *  事件 - 修改权限
 */
- (void)onButtonClicked_Modify:(UIButton*)button
{
    id item = [_dataArray objectAtIndex:button.tag];
    if ([[item objectForKey:@"is_memo"] boolValue]) {
        [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kVcPermissionMemoKeyModifyAskTitle", @"修改备注权限")
                                                          withTitle:nil
                                                        placeholder:NSLocalizedString(@"kVcPermissionMemoKeyModifyInputPlaceholder", @"请输入新的备注公钥")
                                                         ispassword:NO
                                                                 ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                              tfcfg:nil
                                                         completion:^(NSInteger buttonIndex, NSString *tfvalue) {
            if (buttonIndex != 0){
                [_owner GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                    if (unlocked) {
                        [self _onModifyMemoKeyClicked:item newKey:tfvalue];
                    }
                }];
            }
        }];
    } else {
        //  REMARK：查询最大多签成员数量
        [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[ChainObjectManager sharedChainObjectManager] queryGlobalProperties] then:(^id(id data) {
            [_owner hideBlockView];
            id gp = [[ChainObjectManager sharedChainObjectManager] getObjectGlobalProperties];
            id parameters = [gp objectForKey:@"parameters"];
            NSInteger maximum_authority_membership = [[parameters objectForKey:@"maximum_authority_membership"] integerValue];
            WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
            VCPermissionEdit* vc = [[VCPermissionEdit alloc] initWithPermissionJson:item
                                                       maximum_authority_membership:maximum_authority_membership
                                                                     result_promise:result_promise];
            [_owner pushViewController:vc
                               vctitle:NSLocalizedString(@"kVcTitleChangePermission", @"修改权限")
                             backtitle:kVcDefaultBackTitleName];
            [result_promise then:^id(id full_account_data) {
                //  重新刷新列表
                [self _refreshUI:full_account_data];
                return nil;
            }];
            return nil;
        })] catch:(^id(id error) {
            [_owner hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
            return nil;
        })];
    }
}

@end
