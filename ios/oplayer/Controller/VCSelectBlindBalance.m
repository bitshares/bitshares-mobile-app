//
//  VCSelectBlindBalance.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCSelectBlindBalance.h"
#import "ViewBlindBalanceCell.h"

enum
{
    kVcBlindBalance = 0,
    kVcSubmitButton,
    kVcMax
};

@interface VCSelectBlindBalance ()
{
    NSDictionary*           _default_selected;
    WsPromiseObject*        _result_promise;
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
    ViewBlockLabel*         _lbSubmit;
}

@end

@implementation VCSelectBlindBalance

-(void)dealloc
{
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbSubmit = nil;
    _result_promise = nil;
}

- (id)initWithResultPromise:(WsPromiseObject*)result_promise default_selected:(NSDictionary*)default_selected
{
    self = [super init];
    if (self){
        assert(default_selected);
        _dataArray = [NSMutableArray array];
        _result_promise = result_promise;
        _default_selected = default_selected;
    }
    return self;
}

- (void)onQueryBlindBalanceAndDependenceResponsed:(id)data_array
{
    [_dataArray removeAllObjects];
    if (data_array && [data_array count] > 0) {
        for (id blind_balance in data_array) {
            //  添加收据并初始化默认选中状态
            id commitment = [[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"commitment"];
            assert([commitment isKindOfClass:[NSString class]]);
            BOOL selected = [[_default_selected objectForKey:commitment] boolValue];
            [_dataArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   blind_balance, @"_kBlindBalance",
                                   @(selected), @"_kSelected",
                                   nil]];
        }
    }
    
    //  更新UI可见性
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    _lbSubmit.hidden = NO;
}

- (void)queryBlindBalanceAndDependence
{
    id data_array = [[[AppCacheManager sharedAppCacheManager] getAllBlindBalance] allValues];
    NSMutableDictionary* ids = [NSMutableDictionary dictionary];
    for (id blind_balance in data_array) {
        [ids setObject:@YES forKey:[[[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"amount"] objectForKey:@"asset_id"]];
    }
    if ([ids count] > 0) {
        [VcUtils simpleRequest:self
                       request:[[ChainObjectManager sharedChainObjectManager] queryAllGrapheneObjects:[ids allKeys]]
                      callback:^(id data) {
            [self onQueryBlindBalanceAndDependenceResponsed:data_array];
        }];
    } else {
        [self onQueryBlindBalanceAndDependenceResponsed:data_array];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  获取所有收据数据，收据格式：
    //    @"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
    //    @"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
    //    @"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
    //    @"decrypted_memo": @{
    //        @"amount": @{@"asset_id": @"1.3.0", @"amount": @12300000},              //  转账用，显示用。
    //        @"blinding_factor": @"",                                                //  转账用
    //        @"commitment": @"",                                                     //  转账用
    //        @"check": @331,                                                         //  导入check用，显示用。
    //    }
    //    [_dataArray addObjectsFromArray:[[[AppCacheManager sharedAppCacheManager] getAllBlindBalance] allValues]];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.editing = YES;
    _mainTableView.allowsSelectionDuringEditing = YES;
    _mainTableView.allowsMultipleSelectionDuringEditing = YES;
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kVcStTipEmptyNoBlindBalance", @"没有任何隐私收据。")];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    //  确定按钮
    _lbSubmit = [self createCellLableButton:NSLocalizedString(@"kVcStBtnSelectDone", @"确定")];
    _lbSubmit.hidden = YES;
    
    //  查询依赖
    [self queryBlindBalanceAndDependence];
}

#pragma mark- TableView delegate method
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcBlindBalance) {
        return YES;
    }
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleInsert | UITableViewCellEditingStyleDelete;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcBlindBalance) {
        return [_dataArray count];
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcBlindBalance) {
        CGFloat baseHeight = 8.0 + 28 + 24 * 2;
        
        return baseHeight;
    }
    return tableView.rowHeight;
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
    if (indexPath.section == kVcBlindBalance) {
        static NSString* identify = @"id_blind_balance_cell";
        ViewBlindBalanceCell* cell = (ViewBlindBalanceCell*)[tableView dequeueReusableCellWithIdentifier:identify];
        if (!cell)
        {
            cell = [[ViewBlindBalanceCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
            //  REMARK：多选情况下该参数不能设置为 UITableViewCellSelectionStyleNone。
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
        }
        //  多选时不显示蓝色背景
        cell.multipleSelectionBackgroundView = [[UIView alloc] init];
        cell.multipleSelectionBackgroundView.hidden = YES;
        cell.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
        
        id row_data = [_dataArray objectAtIndex:indexPath.row];
        
        cell.showCustomBottomLine = YES;
        cell.row = indexPath.row;
        [cell setItem:[row_data objectForKey:@"_kBlindBalance"]];
        //  默认选中
        if ([[row_data objectForKey:@"_kSelected"] boolValue]){
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
        return cell;
    } else {
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.hideBottomLine = YES;
        cell.hideTopLine = YES;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_lbSubmit cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcBlindBalance) {
        //  选择，可处理事件。
        id row_data = [_dataArray objectAtIndex:indexPath.row];
        assert(row_data);
        //  更新选中状态
        row_data[@"_kSelected"] = @(YES);
    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            [self onSubmitClicked:tableView];
        }];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(3_0)
{
    if (indexPath.section == kVcBlindBalance) {
        //  取消选择，可处理事件。
        id row_data = [_dataArray objectAtIndex:indexPath.row];
        assert(row_data);
        //  更新选中状态
        row_data[@"_kSelected"] = @(NO);
    } else {
        //  ...
    }
}

- (void)onSubmitClicked:(UITableView*)tableView
{
    NSMutableDictionary* ids = [NSMutableDictionary dictionary];
    NSMutableArray* result = [NSMutableArray array];
    
    //  获取所有选中的隐私收据
    for (id row_data in _dataArray) {
        if ([[row_data objectForKey:@"_kSelected"] boolValue]){
            id blind_balance = [row_data objectForKey:@"_kBlindBalance"];
            [result addObject:blind_balance];
            ids[[[[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"amount"] objectForKey:@"asset_id"]] = @YES;
        }
    }
    
    if ([ids count] > 1) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipErrPleaseSelectSameAssetReceipts", @"请选择资产名称相同的收据。")];
        return;
    }
    
    if (_result_promise) {
        [_result_promise resolve:[result copy]];
    }
    [self closeOrPopViewController];
}

@end
