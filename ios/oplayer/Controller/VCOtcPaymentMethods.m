//
//  VCOtcPaymentMethods.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcPaymentMethods.h"

#import "VCOtcAddBankCard.h"
#import "VCOtcAddAlipay.h"

#import "ViewOtcPaymentMethodInfoCell.h"
#import "OtcManager.h"

@interface VCOtcPaymentMethods ()
{
    NSDictionary*           _auth_info;
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCOtcPaymentMethods

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

- (id)initWithAuthInfo:(id)auth_info
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onAddNewPaymentMethodClicked
{
    //  TODO:2.9
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:nil
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:@[@"银行卡", @"支付宝"]
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
         if (buttonIndex != cancelIndex){
             if (buttonIndex == 0){
                 [self pushViewController:[[VCOtcAddBankCard alloc] initWithAuthInfo:_auth_info]
                                  vctitle:@"添加银行卡"//TODO:2.9多语言
                                backtitle:kVcDefaultBackTitleName];
             }else if (buttonIndex ==1){
                 [self pushViewController:[[VCOtcAddAlipay alloc] initWithAuthInfo:_auth_info]
                                  vctitle:@"添加支付宝"//TODO:2.9多语言
                                backtitle:kVcDefaultBackTitleName];
             }else{
                 assert(false);
             }
         }
     }];
}

- (void)onQueryPaymentMethodsResponsed:(id)responsed
{
    id records = [responsed objectForKey:@"data"];
    [_dataArray removeAllObjects];
    if (records) {
        [_dataArray addObjectsFromArray:records];
    }
    [self refreshView];
}

- (void)refreshView
{
    _mainTableView.hidden = [_dataArray count] <= 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

- (void)queryPaymentMethods
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[otc queryPaymentMethods:[otc getCurrentBtsAccount]] then:^id(id data) {
        [self hideBlockView];
        [self onQueryPaymentMethodsResponsed:data];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右上角新增按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onAddNewPaymentMethodClicked)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    _mainTableView.hidden = NO;
    
    //  UI - 空 TODO:2.9
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有任何收款方式，点击右上角添加。"];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    //  查询
    [self queryPaymentMethods];
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
    CGFloat baseHeight = 8.0 + 28 * 3;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_payment_method_info_cell";
    ViewOtcPaymentMethodInfoCell* cell = (ViewOtcPaymentMethodInfoCell*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewOtcPaymentMethodInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.showCustomBottomLine = YES;
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        id item = [_dataArray objectAtIndex:indexPath.row];
        assert(item);
        [self onCellClicked:item];
    }];
}

/*
 *  (private) 点击收款方式
 */
- (void)onCellClicked:(id)item
{
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                      message:nil
                                                       cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                        items:@[@"编辑", @"删除"]
                                                     callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
    {
        if (buttonIndex != cancelIndex){
            //  TODO:2.9
        }
    }];
}

@end
