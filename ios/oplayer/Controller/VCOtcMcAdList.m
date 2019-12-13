//
//  VCOtcMcAdList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcAdList.h"
#import "MBProgressHUDSingleton.h"
#import "ViewOtcAdInfoCell.h"
#import "VCOtcMcAdUpdate.h"
#import "OrgUtils.h"
#import "OtcManager.h"

@interface VCOtcMcAdListPages ()
{
    NSDictionary*   _auth_info;
    NSDictionary*   _merchant_detail;
    EOtcUserType    _user_type;
}

@end

@implementation VCOtcMcAdListPages

-(void)dealloc
{
    _auth_info = nil;
}

- (NSArray*)getTitleStringArray
{
    //  TODO:2.9
    return @[@"上架中", @"已下架", @"已删除"];
}

- (NSArray*)getSubPageVCArray
{
    id vc01 = [[VCOtcMcAdList alloc] initWithOwner:self
                                          authInfo:_auth_info
                                         user_type:_user_type
                                   merchant_detail:_merchant_detail
                                         ad_status:eoads_online];
    id vc02 = [[VCOtcMcAdList alloc] initWithOwner:self
                                          authInfo:_auth_info
                                         user_type:_user_type
                                   merchant_detail:_merchant_detail
                                         ad_status:eoads_offline];
    id vc03 = [[VCOtcMcAdList alloc] initWithOwner:self
                                          authInfo:_auth_info
                                         user_type:_user_type
                                   merchant_detail:_merchant_detail
                                         ad_status:eoads_deleted];
    return @[vc01, vc02, vc03];
}

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
        _user_type = user_type;
        _merchant_detail = merchant_detail;
    }
    return self;
}

- (void)onAddNewPaymentMethodClicked
{
    VCBase* vc = [[VCOtcMcAdUpdate alloc] initWithAuthInfo:_auth_info
                                                 user_type:eout_merchant
                                           merchant_detail:_merchant_detail
                                                   ad_info:nil];
    //  TODO:2.9
    [self pushViewController:vc vctitle:@"发布广告" backtitle:kVcDefaultBackTitleName];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //  Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右上角新增按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onAddNewPaymentMethodClicked)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
    //  查询当前初始页数据
    VCOtcMcAdList* vc = (VCOtcMcAdList*)[self currentPage];
    if (vc) {
        [vc queryMerchantAdList];
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
            [vc queryMerchantAdList];
        }
    }
}

@end

@interface VCOtcMcAdList ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    NSDictionary*           _auth_info;
    NSDictionary*           _merchant_detail;
    EOtcUserType            _user_type;
    EOtcAdStatus            _ad_status;
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmptyOrder;
}

@end

@implementation VCOtcMcAdList

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

- (void)onQueryMerchantAdListResponsed:(id)responsed
{
    id records = [[responsed objectForKey:@"data"] objectForKey:@"records"];
    [_dataArray removeAllObjects];
    if (records) {
        [_dataArray addObjectsFromArray:records];
    }
    [self refreshView];
}

- (void)queryMerchantAdList
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    WsPromise* p1 = [otc queryAdList:_ad_status
                                type:eoadt_all
                          asset_name:@""
                          otcAccount:[_merchant_detail objectForKey:@"otcAccount"]
                                page:0
                           page_size:50];
    [[p1 then:^id(id data) {
        [_owner hideBlockView];
        [self onQueryMerchantAdListResponsed:data];
        return nil;
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (id)initWithOwner:(VCBase*)owner authInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail
          ad_status:(EOtcAdStatus)ad_status
{
    self = [super init];
    if (self) {
        _owner = owner;
        _auth_info = auth_info;
        _merchant_detail = merchant_detail;
        _user_type = user_type;
        _ad_status = ad_status;
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
    //  TODO:2.9
    switch (_ad_status) {
        case eoads_online:
            _lbEmptyOrder.text = @"没有任何广告信息，点击右上角发布广告。";
            break;
        case eoads_offline:
            _lbEmptyOrder.text = @"没有任何广告信息";
            break;
        case eoads_deleted:
            _lbEmptyOrder.text = @"没有任何广告信息";
            break;
        default:
            break;
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
    CGFloat baseHeight = 8 + 24 + 4 + 20 * 2 + 40 + 8;
    
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
    static NSString* identify = @"id_otc_mc_ad_cell";
    ViewOtcAdInfoCell* cell = (ViewOtcAdInfoCell*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewOtcAdInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor clearColor];
    }
    cell.showCustomBottomLine = YES;
    cell.userType = eout_merchant;
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
        [self onAdCellClicked:item];
    }];
}

- (void)onAdCellClicked:(id)ad_info
{
    VCBase* vc = [[VCOtcMcAdUpdate alloc] initWithAuthInfo:_auth_info
                                                 user_type:eout_merchant
                                           merchant_detail:_merchant_detail
                                                   ad_info:ad_info];
    //  TODO:2.9
    [_owner pushViewController:vc vctitle:@"编辑广告" backtitle:kVcDefaultBackTitleName];
    
    //    OtcManager* otc = [OtcManager sharedOtcManager];
    //    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //    WsPromise* p1;
    //    if (_user_type == eout_normal_user) {
    //        p1 = [otc queryUserOrderDetails:[otc getCurrentBtsAccount] order_id:order_item[@"orderId"]];
    //    } else {
    //        p1 = [otc queryMerchantOrderDetails:[otc getCurrentBtsAccount] order_id:order_item[@"orderId"]];
    //    }
    //    [[p1 then:^id(id responsed) {
    //        [_owner hideBlockView];
    ////        //  转到订单详情界面
    ////        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
    ////        VCOtcOrderDetails* vc = [[VCOtcOrderDetails alloc] initWithOrderDetails:[responsed objectForKey:@"data"]
    ////                                                                           auth:_auth_info
    ////                                                                      user_type:_user_type
    ////                                                                 result_promise:result_promise];
    ////        [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
    ////        [result_promise then:^id(id callback_data) {
    ////            [self _onOrderDetailCallback:callback_data];
    ////            return nil;
    ////        }];
    //        return nil;
    //    }] catch:^id(id error) {
    //        [_owner hideBlockView];
    //        [otc showOtcError:error];
    //        return nil;
    //    }];
}

/*
 *  (private) 从订单详情返回
 */
- (void)_onOrderDetailCallback:(id)callback_data
{
    if (callback_data && [callback_data boolValue]) {
        //  订单状态变更：刷新界面
        [self queryMerchantAdList];
    }
}

@end
