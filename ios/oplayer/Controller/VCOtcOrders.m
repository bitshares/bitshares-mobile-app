//
//  VCOtcOrders.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcOrders.h"
#import "ViewOtcOrderInfCell.h"
#import "OrgUtils.h"

#import "VCOtcOrderDetails.h"

#import "OtcManager.h"

@interface VCOtcOrdersPages ()
{
}

@end

@implementation VCOtcOrdersPages

-(void)dealloc
{
}

- (NSArray*)getTitleStringArray
{
    //  TODO:2.9
    return @[NSLocalizedString(@"kVcOrderPageOpenOrders", @"当前订单"), NSLocalizedString(@"kVcOrderPageHistory", @"历史订单")];
}

- (NSArray*)getSubPageVCArray
{
    id vc01 = [[VCOtcOrders alloc] initWithOwner:self current:YES];
    id vc02 = [[VCOtcOrders alloc] initWithOwner:self current:NO];
    return @[vc01, vc02];
}

- (id)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)onQueryUserOrdersResponsed:(id)responsed
{
    id records = [[responsed objectForKey:@"data"] objectForKey:@"records"];
    if (_subvcArrays && records){
        for (VCOtcOrders* vc in _subvcArrays) {
            [vc onQueryUserOrdersResponsed:records];
        }
    }
}

- (void)queryUserOrders
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[OtcManager sharedOtcManager] queryUserOrders:@"wakaka99" type:eoot_all status:eoos_all page:0 page_size:50] then:^id(id data) {
        [self hideBlockView];
        [self onQueryUserOrdersResponsed:data];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [[OtcManager sharedOtcManager] showOtcError:error];
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    //  查询
    [self queryUserOrders];
}

@end

@interface VCOtcOrders ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    BOOL                    _bCurrentOrder;         //  进行中等待
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmptyOrder;
}

@end

@implementation VCOtcOrders

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

- (id)initWithOwner:(VCBase*)owner current:(BOOL)current;
{
    self = [super init];
    if (self) {
        _owner = owner;
        _bCurrentOrder = current;
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

- (void)onQueryUserOrdersResponsed:(NSArray*)data_array
{
    [_dataArray removeAllObjects];
    if (data_array) {
        [_dataArray addObjectsFromArray:data_array];
    }
    [self refreshView];
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
    _mainTableView.hidden = [_dataArray count] <= 0;
    
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
    if (_bCurrentOrder){
        _lbEmptyOrder.text = @"没有任何进行中的订单";
    }else{
        _lbEmptyOrder.text = @"没有任何历史订单信息";
    }
    [self.view addSubview:_lbEmptyOrder];
    _lbEmptyOrder.hidden = !_mainTableView.hidden;
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
    [cell setTagData:indexPath.row];
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
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[OtcManager sharedOtcManager] queryUserOrderDetails:order_item[@"userAccount"] order_id:order_item[@"orderId"]] then:^id(id data) {
        [_owner hideBlockView];
//        [self onQueryUserOrdersResponsed:data];
        //  TODO:2.9
        VCOtcOrderDetails* vc = [[VCOtcOrderDetails alloc] init];
        [_owner pushViewController:vc vctitle:@"订单详情" backtitle:kVcDefaultBackTitleName];
        return nil;
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [[OtcManager sharedOtcManager] showOtcError:error];
        return nil;
    }];
}

@end
