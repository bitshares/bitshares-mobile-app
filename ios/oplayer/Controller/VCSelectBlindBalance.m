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

- (id)init
{
    self = [super init];
    if (self){
        _dataArray = [NSMutableArray array];
        _result_promise = nil;//TODO:6.0 args
//        result_promise:(WsPromiseObject*)result_promise
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
        //    id row_data = [_sectionDataArray[indexPath.section][@"kDataArray"] objectAtIndex:indexPath.row];
        //    assert(row_data);
        //    //  更新选中状态
        //    row_data[@"_kSelected"] = @(YES);
        //    //  更新脏标记
        //    _bDirty = [self _isUserModifyed];
            //  TODO:fowallet 新增、删除标记待处理。
            //    //  有代理人的情况（需要重新刷新table、所有代投票标签都要移除or添加）
            //    if (_have_proxy){
            //        //  TODO:fowallet 3个界面都需要更新
            //        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            //            [tableView reloadData];
            //        }];
            //    }
    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            [self onSubmitClicked];
        }];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(3_0)
{
    if (indexPath.section == kVcBlindBalance) {
        //    id row_data = [_sectionDataArray[indexPath.section][@"kDataArray"] objectAtIndex:indexPath.row];
        //    assert(row_data);
        //    //  更新选中状态
        //    row_data[@"_kSelected"] = @(NO);
        //    //  更新脏标记
        //    _bDirty = [self _isUserModifyed];
            //  TODO:fowallet 新增、删除标记待处理。
            //    //  有代理人的情况（需要重新刷新table、所有代投票标签都要移除or添加）
            //    if (_have_proxy){
            //        //  TODO:fowallet 3个界面都需要更新
            //        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            //            [tableView reloadData];
            //        }];
            //    }
    } else {
        //  ...
    }
}

- (void)onSubmitClicked
{
    if (_result_promise) {
        //  TODO:6.0 get result selected
//        [_result_promise resolve:blind_balance];
    }
    [self closeOrPopViewController];
}

@end
