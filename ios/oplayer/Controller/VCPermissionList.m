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

@interface VCPermissionList ()
{
    __weak VCBase*          _owner;                             //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
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
    [_mainTableView reloadData];
}

- (void)queryDependencyAccountName
{
    NSMutableDictionary* account_id_hash = [NSMutableDictionary dictionary];
    for (id row in _dataArray) {
        for (id item in [row objectForKey:@"items"]) {
            if ([[item objectForKey:@"isaccount"] boolValue]) {
                [account_id_hash setObject:@YES forKey:[item objectForKey:@"key"]];
            }
        }
    }
    if ([account_id_hash count] <= 0) {
        return;
    }
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[ChainObjectManager sharedChainObjectManager] queryAllAccountsInfo:[account_id_hash allKeys]] then:(^id(id data) {
        [self hideBlockView];
        [self _onQueryDependencyAccountNameResponsed];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

/**
 *  (private) 账号权限是否可以修改判断
 */
- (BOOL)_canBeModified:(NSDictionary*)account permission:(id)permission
{
    id oid = [account objectForKey:@"id"];
    if ([oid isEqualToString:BTS_GRAPHENE_COMMITTEE_ACCOUNT] ||
        [oid isEqualToString:BTS_GRAPHENE_TEMP_ACCOUNT] ||
        [oid isEqualToString:BTS_GRAPHENE_PROXY_TO_SELF]) {
        return NO;
    }
    return YES;
}

- (id)_parsePermissionJson:(id)permission title:(NSString*)title account:(id)account
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    assert(permission);
    BOOL canBeModified = [self _canBeModified:account permission:permission];
    //  memo key
    if ([permission isKindOfClass:[NSString class]]) {
        return @{@"title":title, @"weight_threshold":@1,
                 @"is_memo":@YES, @"items":@[@{@"key":permission, @"threshold":@1}], @"canBeModified":@(canBeModified)};
    }
    //  other permission
    NSInteger weight_threshold = [[permission objectForKey:@"weight_threshold"] integerValue];
    id account_auths = [permission objectForKey:@"account_auths"];
    id key_auths = [permission objectForKey:@"key_auths"];
    id address_auths = [permission objectForKey:@"address_auths"];
    NSMutableArray* list = [NSMutableArray array];
    NSInteger curr_threshold = 0;
    for (id item in account_auths) {
        assert([item count] == 2);
        id oid = [item firstObject];
        NSInteger threshold = [[item lastObject] integerValue];
        curr_threshold += threshold;
        id mutable_hash = [NSMutableDictionary dictionaryWithObjectsAndKeys:oid, @"key", @YES, @"isaccount", @(threshold), @"threshold", nil];
        //  查询依赖的名字
        id multi_sign_account = [chainMgr getChainObjectByID:oid];
        if (multi_sign_account) {
            [mutable_hash setObject:multi_sign_account[@"name"] forKey:@"name"];
        }
        [list addObject:mutable_hash];
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
    }
    //  根据权重降序排列
    [list sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSInteger threshold01 = [[obj1 objectForKey:@"threshold"] integerValue];
        NSInteger threshold02 = [[obj2 objectForKey:@"threshold"] integerValue];
        return threshold02 - threshold01;
    })];
    if (curr_threshold >= weight_threshold) {
        return @{@"title":title, @"weight_threshold":@(weight_threshold), @"items":list, @"canBeModified":@(canBeModified), @"raw":permission};
    }
    //  no permission
    return nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  TODO:2.8 多语言
    _dataArray = [[[NSMutableArray array] ruby_apply:(^(id ary) {
        id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
        assert(account);
        id owner = [account objectForKey:@"owner"];
        assert(owner);
        id value = [self _parsePermissionJson:owner title:@"账号权限" account:account];
        if (value) {
            [ary addObject:value];
        }
        
        id active = [account objectForKey:@"active"];
        assert(active);
        value = [self _parsePermissionJson:active title:@"资金权限" account:account];
        if (value) {
            [ary addObject:value];
        }
        
        id memo_key = [[account objectForKey:@"options"] objectForKey:@"memo_key"];
        assert(memo_key);
        value = [self _parsePermissionJson:memo_key title:@"备注权限" account:account];
        if (value) {
            [ary addObject:value];
        }
    })] copy];
    assert([_dataArray count] > 0);
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id item = [_dataArray objectAtIndex:indexPath.section];
    NSInteger line_number = [[item objectForKey:@"items"] count];
    if (![[item objectForKey:@"is_memo"] boolValue]) {
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
    return 44.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
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
        CGSize size1 = [UITableViewCellBase auxSizeWithText:titleLabel.text font:titleLabel.font maxsize:CGSizeMake(fWidth, 9999)];
        UIButton* btnModify = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];//TODO:2.8 TODO:TODO:TODO:
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
        secLabel.attributedText = [UITableViewCellBase genAndColorAttributedText:@"阈值 "
                                                                           value:[NSString stringWithFormat:@"%@", item[@"weight_threshold"]]
                                                                      titleColor:theme.textColorNormal
                                                                      valueColor:theme.textColorMain];
        [myView addSubview:secLabel];
    }
    
    return myView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
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
}

/**
 *  事件 - 修改权限
 */
- (void)onButtonClicked_Modify:(UIButton*)button
{
    id item = [_dataArray objectAtIndex:button.tag];
    if ([[item objectForKey:@"is_memo"] boolValue]) {
        [OrgUtils showMessage:@"memo"];
        return;
    } else {
        //  REMARK：查询最大多签成员数量
        [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[ChainObjectManager sharedChainObjectManager] queryGlobalProperties] then:(^id(id data) {
            [_owner hideBlockView];
            id gp = [[ChainObjectManager sharedChainObjectManager] getObjectGlobalProperties];
            id parameters = [gp objectForKey:@"parameters"];
            NSInteger maximum_authority_membership = [[parameters objectForKey:@"maximum_authority_membership"] integerValue];
            //  TODO:多语言
            VCPermissionEdit* vc = [[VCPermissionEdit alloc] initWithPermissionJson:[item objectForKey:@"raw"] maximum_authority_membership:maximum_authority_membership];
            [_owner pushViewController:vc
                               vctitle:@"修改权限"
                             backtitle:kVcDefaultBackTitleName];
            
            return nil;
            
        })] catch:(^id(id error) {
            [_owner hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
            return nil;
        })];
    }
}

@end
