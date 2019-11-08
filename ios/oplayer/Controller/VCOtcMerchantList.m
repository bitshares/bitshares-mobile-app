//
//  VCOtcMerchantList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMerchantList.h"
#import "ViewOtcMerchantInfoCell.h"
#import "MBProgressHUDSingleton.h"

@interface VCOtcMerchantListPages ()
{
}

@end

@implementation VCOtcMerchantListPages

-(void)dealloc
{
}

- (NSArray*)getTitleStringArray
{
    //  TODO:2.9
    return @[@"我要买", @"我要卖"];
//    return [_assetList ruby_map:(^id(id src) {
//        return [src objectForKey:@"symbol"];
//    })];
}

- (NSArray*)getSubPageVCArray
{
    //  TODO:2.9
    return @[[[VCOtcMerchantList alloc] initWithOwner:self userbuy:YES],
             [[VCOtcMerchantList alloc] initWithOwner:self userbuy:NO]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  REMARK：请求第一页数据
    [self queryMerchantInfoList:1];
}

- (void)queryMerchantInfoList:(NSInteger)tag
{
//    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //    get_call_orders && get_full_accounts
    
//    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
//
//    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
//
//    id p1 = [api exec:@"get_call_orders" params:@[[asset objectForKey:@"id"], @50]];
//    id p2 = [[api exec:@"get_objects" params:@[@[[asset objectForKey:@"bitasset_data_id"]]]] then:(^id(id data) {
//        return [data objectAtIndex:0];
//    })];
//
//    [[[WsPromise all:@[p1, p2]] then:(^id(id data) {
//        id borrower_list = [data[0] ruby_map:(^id(id src) {
//            return src[@"borrower"];
//        })];
//        return [[chainMgr queryAllAccountsInfo:borrower_list] then:(^id(id borrower_hash) {
//            //  (void)borrower_hash 不需要
//            [self onQueryCallOrderResponsed:data tag:tag];
//            [self hideBlockView];
//            return nil;
//        })];
//    })] catch:(^id(id error) {
//        [self hideBlockView];
//        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
//        return nil;
//    })];
    //  TODO:2.9 data?
    [self onMerchantListResponsed:@[] tag:tag];
}

- (void)onPageChanged:(NSInteger)tag
{
    NSLog(@"onPageChanged: %@", @(tag));
    
    //  gurad
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]){
        return;
    }
    
    [self queryMerchantInfoList:tag];
}

- (void)onMerchantListResponsed:(id)data tag:(NSInteger)tag
{
    if (_subvcArrays){
        VCOtcMerchantList* vc = [_subvcArrays objectAtIndex:tag-1];
        [vc onMerchantListResponsed:data];
    }
}

@end

@interface VCOtcMerchantList ()
{
    __weak VCBase*      _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    
    BOOL                _userbuy;       //  用户买入界面（商家卖出）
    UITableViewBase*    _mainTableView;
    UILabel*            _lbEmpty;
    
    NSMutableArray*     _data_array;
}

@end

@implementation VCOtcMerchantList

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbEmpty = nil;
    _data_array = nil;
    _owner = nil;
}

- (id)initWithOwner:(VCBase*)owner userbuy:(BOOL)userbuy
{
    self = [super init];
    if (self) {
        // Custom initialization
        _userbuy = userbuy;
        _owner = owner;
        _data_array = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    // Do any additional setup after loading the view.
    CGRect rect = [self rectWithoutNaviAndPageBar];
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    [self.view addSubview:_mainTableView];

    //  TODO:2.9
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有任何商家在线。"];
//    _lbEmpty.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_lbEmpty];
}

- (void)onMerchantListResponsed:(id)data
{
    [_data_array removeAllObjects];
    
    //  TODO:2.9 TODO:
    id testdata01 = @{};
    [_data_array addObject:testdata01];
    [_data_array addObject:testdata01];
    [_data_array addObject:testdata01];
    
    //  动态设置UI的可见性
    if ([_data_array count] > 0){
        _mainTableView.hidden = NO;
        _lbEmpty.hidden = YES;
        [_mainTableView reloadData];
    }else{
        _mainTableView.hidden = YES;
        _lbEmpty.hidden = NO;
    }
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_data_array count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8 + 24 + 4 + 20 * 2 + 8;
    
    return baseHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 8.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 8.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_merchant_cell";
    ViewOtcMerchantInfoCell* cell = (ViewOtcMerchantInfoCell*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewOtcMerchantInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor clearColor];
    }
    cell.showCustomBottomLine = YES;
    cell.isBuy = _userbuy;
    [cell setItem:[_data_array objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        id item = [_data_array objectAtIndex:indexPath.row];
        assert(item);
        //  TODO:2.9 onclicked
    }];
}

@end

