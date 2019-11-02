//
//  VCMyContact.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCMyContact.h"

@interface VCMyContact ()
{
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCMyContact

-(void)dealloc
{
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self){
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)_addMyContactCore
{
    //  TODO:2.9
    id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(account);
    
    id contact =@[ @{
                       @"address":@"1.2.1",
                       @"blockchain":@"bitshares",
                       @"priority":@100,
                       @"name":@"见证人多签的账号o.o"
    }];
    id value1 = [contact to_json];
    //    id value2 = [@"jsonvalue2" to_json];
    id opdata = @{
        @"remove":@NO,
        @"catalog":@"kBcdssContactList",
        @"key_values":@[@[@"1.2.1", value1]]
    };
    
    [[[[BitsharesClientManager sharedBitsharesClientManager] accountStorageMap:account[@"id"] opdata:opdata] then:^id(id data) {
        NSLog(@"%@", data);
        return nil;
    }] catch:^id(id error) {
        NSLog(@"%@", error);
        return nil;
    }];
}

- (void)_onQueryMyContactInfoResponsed:(id)data
{
    //  TODO:6.1
    //  TODO:add data to _dataArray
    
    //  更新显示
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
    
}

- (void)queryMyContactInfo
{
    assert([[WalletManager sharedWalletManager] isWalletExist]);
    id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(account);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  TODO:2.9 TODO:3.0 catalog key
    [[[chainMgr queryAccountStorageInfo:[account objectForKey:@"id"] catalog:@"kBcdssContactList"] then:^id(id data) {
        [self hideBlockView];
        [self _onQueryMyContactInfoResponsed:data];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

- (void)onAddNewContact
{
    //  TODO:6.1
    [self _addMyContactCore];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右上角新增按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onAddNewContact)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空 TODO:6.1 lang
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有任何联系人信息"];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    //  查询
    [self queryMyContactInfo];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataArray count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28 + 24 * 2;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //    static NSString* identify = @"id_vesting_info_cell";
    //    ViewVestingBalanceCell* cell = (ViewVestingBalanceCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    //    if (!cell)
    //    {
    //        cell = [[ViewVestingBalanceCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:_isSelfAccount ? self : nil];
    //        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    //        cell.accessoryType = UITableViewCellAccessoryNone;
    //    }
    //    cell.showCustomBottomLine = YES;
    //    cell.row = indexPath.row;
    //    [cell setTagData:indexPath.row];
    //    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    //    return cell;
    //  TODO:2.9
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
