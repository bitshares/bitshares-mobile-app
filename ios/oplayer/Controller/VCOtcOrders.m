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
        //  TODO:2.9
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
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
        //  TODO:2.9
        _dataArray = @[@{},@{}];
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

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark- for actions

- (void)processCancelOrderCore:(id)order fee_item:(id)fee_item
{
   
}

- (void)onButtonClicked_CancelOrder:(UIButton*)button
{
//    if (_isHistory){
//        return;
//    }
//
//    assert(_fullUserData);
//
//    id order = [_dataArray objectAtIndex:button.tag];
//    NSLog(@"cancel : %@", order[@"id"]);
//
//    id raw_order = [order objectForKey:@"raw_order"];
//    id extra_balance = @{raw_order[@"sell_price"][@"base"][@"asset_id"]:raw_order[@"for_sale"]};
//
//    id fee_item = [[ChainObjectManager sharedChainObjectManager] getFeeItem:ebo_limit_order_cancel
//                                                          full_account_data:_fullUserData
//                                                              extra_balance:extra_balance];
//    assert(fee_item);
//    if (![[fee_item objectForKey:@"sufficient"] boolValue]){
//        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
//        return;
//    }
//
//    [_owner GuardWalletUnlocked:NO body:^(BOOL unlocked) {
//        if (unlocked){
//            //  TODO:fowallet !!! 取消订单是否二次确认。
//            [self processCancelOrderCore:order fee_item:fee_item];
//        }
//    }];
}

@end
