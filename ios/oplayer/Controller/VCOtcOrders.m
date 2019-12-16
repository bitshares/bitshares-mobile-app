//
//  VCOtcOrders.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcOrders.h"
#import "MBProgressHUDSingleton.h"
#import "ViewOtcOrderInfCell.h"
#import "OrgUtils.h"
#import "VCOtcOrderDetails.h"
#import "OtcManager.h"

@interface VCOtcOrdersPages ()
{
    NSDictionary*   _auth_info;
    EOtcUserType    _user_type;
}

@end

@implementation VCOtcOrdersPages

-(void)dealloc
{
    _auth_info = nil;
}

- (NSInteger)getTitleDefaultSelectedIndex
{
    //  商家端：默认选中【需处理】标签
    return _user_type == eout_normal_user ? 1 : 2;
}

- (NSArray*)getTitleStringArray
{
    if (_user_type == eout_normal_user) {
        return @[NSLocalizedString(@"kOtcOrderPageTitlePending", @"进行中"),
                 NSLocalizedString(@"kOtcOrderPageTitleCompleted", @"已完成"),
                 NSLocalizedString(@"kOtcOrderPageTitleCancelled", @"已取消")];
    } else {
        return @[NSLocalizedString(@"kOtcOrderPageTitleAll", @"全部"),
                 NSLocalizedString(@"kOtcOrderPageTitleWaitProcessing", @"需处理"),
                 NSLocalizedString(@"kOtcOrderPageTitlePending", @"进行中"),
                 NSLocalizedString(@"kOtcOrderPageTitleCompleted", @"已完成")];
    }
}

- (NSArray*)getSubPageVCArray
{
    if (_user_type == eout_normal_user) {
        id vc01 = [[VCOtcOrders alloc] initWithOwner:self authInfo:_auth_info user_type:_user_type order_status:eoos_pending];
        id vc02 = [[VCOtcOrders alloc] initWithOwner:self authInfo:_auth_info user_type:_user_type order_status:eoos_completed];
        id vc03 = [[VCOtcOrders alloc] initWithOwner:self authInfo:_auth_info user_type:_user_type order_status:eoos_cancelled];
        return @[vc01, vc02, vc03];
    } else {
        id vc01 = [[VCOtcOrders alloc] initWithOwner:self authInfo:_auth_info user_type:_user_type order_status:eoos_all];
        id vc02 = [[VCOtcOrders alloc] initWithOwner:self authInfo:_auth_info user_type:_user_type order_status:eoos_mc_wait_process];
        id vc03 = [[VCOtcOrders alloc] initWithOwner:self authInfo:_auth_info user_type:_user_type order_status:eoos_mc_pending];
        id vc04 = [[VCOtcOrders alloc] initWithOwner:self authInfo:_auth_info user_type:_user_type order_status:eoos_mc_done];
        return @[vc01, vc02, vc03, vc04];
    }
}

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
        _user_type = user_type;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //  Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    //  查询当前初始页数据
    VCOtcOrders* vc = (VCOtcOrders*)[self currentPage];
    if (vc) {
        [vc queryCurrentPageOrders];
    }
}

- (void)onPageChanged:(NSInteger)tag
{
    NSLog(@"onPageChanged: %@", @(tag));
    
    //  gurad
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]){
        return;
    }
    
    //  query
    if (_subvcArrays){
        id vc = [_subvcArrays safeObjectAtIndex:tag - 1];
        if (vc){
            [vc queryCurrentPageOrders];
        }
    }
}

@end

@interface VCOtcOrders ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    NSDictionary*           _auth_info;
    EOtcUserType            _user_type;
    EOtcOrderStatus         _order_status;
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmptyOrder;
}

@end

@implementation VCOtcOrders

-(void)dealloc
{
    _owner = nil;
    _auth_info = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (void)onQueryCurrentPageOrdersResponsed:(id)responsed
{
    id records = [[responsed objectForKey:@"data"] objectForKey:@"records"];
    [_dataArray removeAllObjects];
    if (records) {
        [_dataArray addObjectsFromArray:records];
    }
    [self refreshView];
}

- (void)queryCurrentPageOrders
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    WsPromise* p1;
    if (_user_type == eout_normal_user) {
        p1 = [otc queryUserOrders:[otc getCurrentBtsAccount] type:eoot_query_all status:_order_status page:0 page_size:50];
    } else {
        p1 = [otc queryMerchantOrders:[otc getCurrentBtsAccount] type:eoot_query_all status:_order_status page:0 page_size:50];
    }
    [[p1 then:^id(id data) {
        [_owner hideBlockView];
        [self onQueryCurrentPageOrdersResponsed:data];
        return nil;
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (id)initWithOwner:(VCBase*)owner authInfo:(id)auth_info user_type:(EOtcUserType)user_type order_status:(EOtcOrderStatus)order_status
{
    self = [super init];
    if (self) {
        _owner = owner;
        _auth_info = auth_info;
        _user_type = user_type;
        _order_status = order_status;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)refreshView
{
    _mainTableView.hidden = [_dataArray count] <= 0;
    _lbEmptyOrder.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
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
    
    //  UI - 空
    _lbEmptyOrder = [[UILabel alloc] initWithFrame:rect];
    _lbEmptyOrder.lineBreakMode = NSLineBreakByWordWrapping;
    _lbEmptyOrder.numberOfLines = 1;
    _lbEmptyOrder.contentMode = UIViewContentModeCenter;
    _lbEmptyOrder.backgroundColor = [UIColor clearColor];
    _lbEmptyOrder.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _lbEmptyOrder.textAlignment = NSTextAlignmentCenter;
    _lbEmptyOrder.font = [UIFont boldSystemFontOfSize:13];
    if (_user_type == eout_merchant && _order_status == eoos_mc_wait_process) {
        _lbEmptyOrder.text = NSLocalizedString(@"kOtcOrderEmptyLabelWaitProcessing", @"没有任何需处理的订单");
    } else {
        _lbEmptyOrder.text = NSLocalizedString(@"kOtcOrderEmptyLabel", @"没有任何订单信息");
    }
    
    [self.view addSubview:_lbEmptyOrder];
    _lbEmptyOrder.hidden = YES;
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
    CGFloat baseHeight = 8.0 + 28 + 24 * 3;

    return baseHeight;
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
    static NSString* identify = @"id_otc_orders";
    ViewOtcOrderInfCell* cell = (ViewOtcOrderInfCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewOtcOrderInfCell alloc] initWithStyle:UITableViewCellStyleValue1
                                          reuseIdentifier:identify
                                                       vc:self];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.showCustomBottomLine = YES;
    cell.userType = _user_type;
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        id item = [_dataArray objectAtIndex:indexPath.row];
        assert(item);
        [self onOrderCellClicked:item];
    }];
}

- (void)onOrderCellClicked:(id)order_item
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    WsPromise* p1;
    if (_user_type == eout_normal_user) {
        p1 = [otc queryUserOrderDetails:[otc getCurrentBtsAccount] order_id:order_item[@"orderId"]];
    } else {
        p1 = [otc queryMerchantOrderDetails:[otc getCurrentBtsAccount] order_id:order_item[@"orderId"]];
    }
    [[p1 then:^id(id responsed) {
        [_owner hideBlockView];
        //  转到订单详情界面
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCOtcOrderDetails* vc = [[VCOtcOrderDetails alloc] initWithOrderDetails:[responsed objectForKey:@"data"]
                                                                           auth:_auth_info
                                                                      user_type:_user_type
                                                                 result_promise:result_promise];
        [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        [result_promise then:^id(id callback_data) {
            [self _onOrderDetailCallback:callback_data];
            return nil;
        }];
        return nil;
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

/*
 *  (private) 从订单详情返回
 */
- (void)_onOrderDetailCallback:(id)callback_data
{
    if (callback_data && [callback_data boolValue]) {
        //  订单状态变更：刷新界面
        [self queryCurrentPageOrders];
    }
}

@end
