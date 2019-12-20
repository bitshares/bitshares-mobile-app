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
    return @[NSLocalizedString(@"kOtcMcAdPageTitleOnline", @"上架中"),
             NSLocalizedString(@"kOtcMcAdPageTitleOffline", @"已下架"),
             NSLocalizedString(@"kOtcMcAdPageTitleDeleted", @"已删除")];
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

- (void)refreshCurrentAdPage
{
    VCOtcMcAdList* vc = (VCOtcMcAdList*)[self currentPage];
    if (vc) {
        [vc queryMerchantAdList];
    }
}

- (void)onAddNewAdClicked
{
    WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
    VCBase* vc = [[VCOtcMcAdUpdate alloc] initWithAuthInfo:_auth_info
                                                 user_type:eout_merchant
                                           merchant_detail:_merchant_detail
                                                   ad_info:nil
                                            result_promise:result_promise];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleOtcMcCreateAd", @"发布广告") backtitle:kVcDefaultBackTitleName];
    [result_promise then:^id(id dirty) {
        //  刷新UI
        if (dirty && [dirty boolValue]) {
            [self refreshCurrentAdPage];
        }
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //  Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右上角新增按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onAddNewAdClicked)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
    //  查询当前初始页数据
    [self refreshCurrentAdPage];
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
    switch (_ad_status) {
        case eoads_online:
            _lbEmptyOrder.text = NSLocalizedString(@"kOtcMcAdTableNoOnlineAd", @"没有任何广告信息，点击右上角发布广告。");
            break;
        case eoads_offline:
            _lbEmptyOrder.text = NSLocalizedString(@"kOtcMcAdTableNoAd", @"没有任何广告信息");
            break;
        case eoads_deleted:
            _lbEmptyOrder.text = NSLocalizedString(@"kOtcMcAdTableNoAd", @"没有任何广告信息");
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
    //  TODO:2.9 已删除的广告暂时不可查看，也不可编辑了。
    if (_ad_status == eoads_deleted) {
        return;
    }
    
    WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
    VCBase* vc = [[VCOtcMcAdUpdate alloc] initWithAuthInfo:_auth_info
                                                 user_type:eout_merchant
                                           merchant_detail:_merchant_detail
                                                   ad_info:ad_info
                                            result_promise:result_promise];
    [_owner pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleOtcMcUpdateAd", @"编辑广告") backtitle:kVcDefaultBackTitleName];
    [result_promise then:^id(id dirty) {
        //  刷新UI
        if (dirty && [dirty boolValue]) {
            [self queryMerchantAdList];
        }
        return nil;
    }];
}

/*
 *  事件 - 上架or下架按钮点击。
 */
- (void)onSubmitButtonClicked:(UIButton*)sender
{
    assert(sender.tag < [_dataArray count]);
    id adInfos = [_dataArray objectAtIndex:sender.tag];
    assert(adInfos);
    
    switch ([[adInfos objectForKey:@"status"] integerValue]) {
        case eoads_online:
        {
            [_owner GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                if (unlocked) {
                    [self _execAdDownCore:adInfos];
                }
            }];
        }
            break;
        case eoads_offline:
        {
            [_owner GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                if (unlocked) {
                    [self _execAdReupCore:adInfos];
                }
            }];
        }
            break;
        case eoads_deleted:
            break;
        default:
            break;
    }
}

- (void)_execAdDownCore:(id)adInfos
{
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    OtcManager* otc = [OtcManager sharedOtcManager];
    [[[otc merchantDownAd:[otc getCurrentBtsAccount] ad_id:[adInfos objectForKey:@"adId"]] then:^id(id data) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipsDownOK", @"已下架。")];
        //  刷新
        [self queryMerchantAdList];
        return nil;
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (void)_execAdReupCore:(id)adInfos
{
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    OtcManager* otc = [OtcManager sharedOtcManager];
    [[[otc merchantReUpAd:[otc getCurrentBtsAccount] ad_id:[adInfos objectForKey:@"adId"]] then:^id(id data) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAdSubmitTipsUpOK", @"已上架。")];
        //  刷新
        [self queryMerchantAdList];
        return nil;
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

@end
