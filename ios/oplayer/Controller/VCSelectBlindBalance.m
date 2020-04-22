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

- (id)initWithResultPromise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self){
        _dataArray = [NSMutableArray array];
        _result_promise = result_promise;
//        id commitment = [[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"commitment"];
    }
    return self;
}

- (void)refreshUI
{
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
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
    [_dataArray addObjectsFromArray:[[[AppCacheManager sharedAppCacheManager] getAllBlindBalance] allValues]];
    
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
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有任何隐私资产，可点击右上角导入转账收据。"];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    [self refreshUI];
    
    //  确定按钮
    _lbSubmit = [self createCellLableButton:@"确定"];
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
        
        cell.showCustomBottomLine = YES;
        cell.row = indexPath.row;
        [cell setTagData:indexPath.row];
        [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
        
        //  TODO:6.0
//        //  默认选中
//        if ([[row_data objectForKey:@"_kSelected"] boolValue]){
//            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
//        }
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
    } else {
        //  ...
    }
}

- (void)onSubmitClicked:(UITableView*)tableView
{
    NSMutableArray* result = [NSMutableArray array];
    for (NSUInteger row = 0; row < [_dataArray count]; ++row) {
        NSIndexPath* path = [NSIndexPath indexPathForRow:row inSection:kVcBlindBalance];
        UITableViewCell* cell = (UITableViewCell*)[tableView cellForRowAtIndexPath:path];
        assert(cell);
        if (cell.selected) {
            [result addObject:[_dataArray objectAtIndex:row]];
        }
    }
    if (_result_promise) {
        [_result_promise resolve:[result copy]];
    }
    [self closeOrPopViewController];
}

@end
