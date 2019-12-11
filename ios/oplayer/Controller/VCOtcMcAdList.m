//
//  VCOtcMcAdList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcAdList.h"
#import "ViewOtcOrderInfCell.h"
#import "OrgUtils.h"
#import "VCOtcOrderDetails.h"
#import "OtcManager.h"

@interface VCOtcMcAdList ()
{
    NSDictionary*           _auth_info;
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmptyOrder;
}

@end

@implementation VCOtcMcAdList

-(void)dealloc
{
    _auth_info = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (void)onQueryUserOrdersResponsed:(id)responsed
{
    id records = [[responsed objectForKey:@"data"] objectForKey:@"records"];
    [_dataArray removeAllObjects];
    if (records) {
        [_dataArray addObjectsFromArray:records];
    }
    [self refreshView];
}

- (void)queryUserOrders
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[otc queryUserOrders:[otc getCurrentBtsAccount] type:eoot_query_all status:eoos_all page:0 page_size:50] then:^id(id data) {
        [self hideBlockView];
        [self onQueryUserOrdersResponsed:data];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (id)initWithAuthInfo:(id)auth_info
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
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
    CGRect rect = [self rectWithoutNavi];
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
    //  TODO:2.9
    _lbEmptyOrder.text = @"没有任何订单信息";
    [self.view addSubview:_lbEmptyOrder];
    _lbEmptyOrder.hidden = YES;
    
    //  查询
    [self queryUserOrders];
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
//    [cell setTagData:indexPath.row];
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
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[otc queryUserOrderDetails:order_item[@"userAccount"] order_id:order_item[@"orderId"]] then:^id(id responsed) {
        [self hideBlockView];
        //  转到订单详情界面
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCOtcOrderDetails* vc = [[VCOtcOrderDetails alloc] initWithOrderDetails:[responsed objectForKey:@"data"]
                                                                           auth:_auth_info
                                                                 result_promise:result_promise];
        [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        [result_promise then:^id(id callback_data) {
            [self _onOrderDetailCallback:callback_data];
            return nil;
        }];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
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
        [self queryUserOrders];
    }
}

@end
