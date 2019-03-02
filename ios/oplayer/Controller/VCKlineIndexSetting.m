//
//  VCKlineIndexSetting.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCKlineIndexSetting.h"
#import "BitsharesClientManager.h"
#import "OrgUtils.h"

enum
{
    kFieldMain = 0,
    kFieldSub,
    kFieldCommit,
    
    kFieldMax
};

@interface VCKlineIndexSetting ()
{
    WsPromiseObject*        _result_promise;
    BOOL                    _bResultCannelled;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _btnCommit;
    
    NSMutableArray*         _pickerDataArray;
    
    NSMutableDictionary*    _configValueHash;
}

@end

@implementation VCKlineIndexSetting

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _pickerDataArray = nil;
    _btnCommit = nil;
    _result_promise = nil;
}

- (id)initWithResultPromise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        // Custom initialization
        _result_promise = result_promise;
        _bResultCannelled = YES;
        _pickerDataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onCancelButtonClicked:(id)sender
{
    _bResultCannelled = YES;
    [self closeModelViewController:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    _configValueHash = [OrgUtils deepClone:[[SettingManager sharedSettingManager] getKLineIndexInfos]];
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  导航条按钮
    [self showLeftButton:NSLocalizedString(@"kBtnCancel", @"取消") action:@selector(onCancelButtonClicked:)];
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    _btnCommit = [self createCellLableButton:NSLocalizedString(@"kVcConfirmSubmitOK", @"确定")];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (_result_promise){
        [_result_promise resolve:@(_bResultCannelled)];
    }
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    //  save
    [[SettingManager sharedSettingManager] setUseConfig:kSettingKey_KLineIndexInfo obj:[_configValueHash copy]];
    //  close
    _bResultCannelled = NO;
    [self closeModelViewController:nil];
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kFieldMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger base = 1;
    if (section == kFieldMain){
        id main_value = [_configValueHash objectForKey:@"kMain"];
        if (![main_value isEqualToString:@""]){
            base += [[_configValueHash objectForKey:[NSString stringWithFormat:@"%@_value", main_value]] count];
        }
    }else if (section == kFieldSub){
        id sub_value = [_configValueHash objectForKey:@"kSub"];
        if (![sub_value isEqualToString:@""]){
            base += [[_configValueHash objectForKey:[NSString stringWithFormat:@"%@_value", sub_value]] count];
        }
    }
    return base;
}

//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
//{
//    return tableView.sectionHeaderHeight;
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
//{
//    if (section == 0){
//        return 20.0f;
//    }
//    return tableView.sectionFooterHeight;
//}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //  TODO:多语言
    switch (indexPath.section) {
        case kFieldMain:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            id main_value = [_configValueHash objectForKey:@"kMain"];
            if (indexPath.row == 0){
                cell.textLabel.text = NSLocalizedString(@"kKlineIndexCellMain", @"主图");
                cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                if ([main_value isEqualToString:@""]){
                    cell.detailTextLabel.text = NSLocalizedString(@"kKlineIndexCellHide", @"不显示");
                }else{
                    cell.detailTextLabel.text = [main_value uppercaseString];
                }
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
            }else{
                cell.textLabel.font = [UIFont systemFontOfSize:13];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
                id value_values = [_configValueHash objectForKey:[NSString stringWithFormat:@"%@_value", main_value]];
                if ([main_value isEqualToString:@"ma"] || [main_value isEqualToString:@"ema"]){
                    UIColor* color = [ThemeManager sharedThemeManager].ma5Color;
                    if (indexPath.row == 2){
                        color = [ThemeManager sharedThemeManager].ma10Color;
                    }else if (indexPath.row == 3){
                        color = [ThemeManager sharedThemeManager].ma30Color;
                    }
                    cell.textLabel.text = [NSString stringWithFormat:@"%@%@", [main_value uppercaseString], @(indexPath.row)];
                    cell.textLabel.textColor = color;
                    NSInteger ma_or_ema_value = [[value_values objectAtIndex:indexPath.row - 1] integerValue];
                    if (ma_or_ema_value > 0){
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", @(ma_or_ema_value)];
                    }else{
                        cell.detailTextLabel.text = NSLocalizedString(@"kKlineIndexCellHide", @"不显示");
                    }
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
                }else if ([main_value isEqualToString:@"boll"]){
                    if (indexPath.row == 1){
                        cell.textLabel.text = NSLocalizedString(@"kKlineIndexCellBollN", @"BOLL N");
                        cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [value_values objectForKey:@"n"]];
                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
                    }else{
                        cell.textLabel.text = NSLocalizedString(@"kKlineIndexCellBollP", @"BOLL P");
                        cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [value_values objectForKey:@"p"]];
                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
                    }
                }
            }
            return cell;
        }
            break;
        case kFieldSub:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            id sub_value = [_configValueHash objectForKey:@"kSub"];
            if (indexPath.row == 0){
                cell.textLabel.text = NSLocalizedString(@"kKlineIndexCellSub", @"副图");
                cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                if ([sub_value isEqualToString:@""]){
                    cell.detailTextLabel.text = NSLocalizedString(@"kKlineIndexCellHide", @"不显示");
                }else{
                    cell.detailTextLabel.text = [sub_value uppercaseString];
                }
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
            }else{
                cell.textLabel.font = [UIFont systemFontOfSize:13];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
                id value_values = [_configValueHash objectForKey:[NSString stringWithFormat:@"%@_value", sub_value]];
                if ([sub_value isEqualToString:@"macd"]){
                    if (indexPath.row == 1){
                        cell.textLabel.text = NSLocalizedString(@"kKlineIndexCellMacdS", @"MACD S");
                        cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [value_values objectForKey:@"s"]];
                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
                    }else if (indexPath.row == 2){
                        cell.textLabel.text = NSLocalizedString(@"kKlineIndexCellMacdL", @"MACD L");
                        cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [value_values objectForKey:@"l"]];
                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
                    }else{
                        cell.textLabel.text = NSLocalizedString(@"kKlineIndexCellMacdM", @"MACD M");
                        cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [value_values objectForKey:@"m"]];
                        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
                    }
                }
            }
            return cell;
        }
            break;
        default:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_btnCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
    }
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kFieldMain:
            {
                if (indexPath.row == 0){
                    id list = @[
                                @{@"name":NSLocalizedString(@"kKlineIndexCellHide", @"不显示"), @"value":@""},
                                @{@"name":@"MA", @"value":@"ma"},
                                @{@"name":@"EMA", @"value":@"ema"},
                                @{@"name":@"BOLL", @"value":@"boll"},
                                ];
                    [VCCommonLogic showPicker:self object_lists:list key:@"name" title:nil callback:^(id selectItem) {
                        if (![[_configValueHash objectForKey:@"kMain"] isEqualToString:selectItem[@"value"]]){
                            [_configValueHash setObject:selectItem[@"value"] forKey:@"kMain"];
                            [_mainTableView reloadData];
                        }
                    }];
                }else{
                    id main_value = [_configValueHash objectForKey:@"kMain"];
                    if ([main_value isEqualToString:@"ma"]){
                        [self _onMaFieldClicked:indexPath.row];
                    }else if ([main_value isEqualToString:@"ema"]){
                        [self _onEmaFieldClicked:indexPath.row];
                    }else if ([main_value isEqualToString:@"boll"]){
                        [self _onBollFieldClicked:indexPath.row];
                    }
                }
            }
                break;
            case kFieldSub:
            {
                if (indexPath.row == 0){
                    id list = @[
                                @{@"name":NSLocalizedString(@"kKlineIndexCellHide", @"不显示"), @"value":@""},
                                @{@"name":@"MACD", @"value":@"macd"},
                                ];
                    [VCCommonLogic showPicker:self object_lists:list key:@"name" title:nil callback:^(id selectItem) {
                        if (![[_configValueHash objectForKey:@"kSub"] isEqualToString:selectItem[@"value"]]){
                            [_configValueHash setObject:selectItem[@"value"] forKey:@"kSub"];
                            [_mainTableView reloadData];
                        }
                    }];
                }else{
                    id sub_value = [_configValueHash objectForKey:@"kSub"];
                    if ([sub_value isEqualToString:@"macd"]){
                        [self _onMacdFieldClicked:indexPath.row];
                    }
                }
            }
                break;
            case kFieldCommit:
                [self onCommitCore];
                break;
            default:
                break;
        }
    }];
}

- (void)_onMaFieldClicked:(NSInteger)row
{
    //  data source
    [_pickerDataArray removeAllObjects];
    
    NSInteger ma_value_min = 2;
    NSInteger ma_value_max = 90;
    [_pickerDataArray addObject:@0];    //  0 means 'hide'
    for (NSInteger ma_value = ma_value_min; ma_value <= ma_value_max; ++ma_value) {
        [_pickerDataArray addObject:[NSString stringWithFormat:@"%@", @(ma_value)]];
    }
    NSInteger current_ma_vlaue = [[[_configValueHash objectForKey:@"ma_value"] objectAtIndex:row - 1] integerValue];
    NSInteger current_ma_value_index = current_ma_vlaue - ma_value_min + 1;
    
    //  show
    ViewSimulateActionSheet* sheet = [ViewSimulateActionSheet styleDefault];
    sheet.tag = row;
    sheet.custom_tag = @"ma";
    sheet.pickerView.tag = row;
    sheet.delegate = self;
    //  selected
    [sheet selectRow:current_ma_value_index inComponent:0 animated:NO];
    [sheet showInView:self.navigationController.view];
}

- (void)_onEmaFieldClicked:(NSInteger)row
{
    //  data source
    [_pickerDataArray removeAllObjects];
    
    NSInteger ema_value_min = 2;
    NSInteger ema_value_max = 90;
    [_pickerDataArray addObject:@0];    //  0 means 'hide'
    for (NSInteger ema_value = ema_value_min; ema_value <= ema_value_max; ++ema_value) {
        [_pickerDataArray addObject:[NSString stringWithFormat:@"%@", @(ema_value)]];
    }
    NSInteger current_ma_vlaue = [[[_configValueHash objectForKey:@"ema_value"] objectAtIndex:row - 1] integerValue];
    NSInteger current_ma_value_index = current_ma_vlaue - ema_value_min + 1;
    
    //  show
    ViewSimulateActionSheet* sheet = [ViewSimulateActionSheet styleDefault];
    sheet.tag = row;
    sheet.custom_tag = @"ema";
    sheet.pickerView.tag = row;
    sheet.delegate = self;
    //  selected
    [sheet selectRow:current_ma_value_index inComponent:0 animated:NO];
    [sheet showInView:self.navigationController.view];
}

- (void)_onBollFieldClicked:(NSInteger)row
{
    //  data source
    [_pickerDataArray removeAllObjects];
    
    NSInteger current_index = 0;
    
    if (row == 1){
        //  select n
        NSInteger n_value_min = 2;
        NSInteger n_value_max = 90;
        for (NSInteger n_value = n_value_min; n_value <= n_value_max; ++n_value) {
            [_pickerDataArray addObject:[NSString stringWithFormat:@"%@", @(n_value)]];
        }
        NSInteger current_n_vlaue = [[[_configValueHash objectForKey:@"boll_value"] objectForKey:@"n"] integerValue];
        current_index = current_n_vlaue - n_value_min;
    }else{
        //  select p
        NSInteger p_value_min = 2;
        NSInteger p_value_max = 9;
        for (NSInteger p_value = p_value_min; p_value <= p_value_max; ++p_value) {
            [_pickerDataArray addObject:[NSString stringWithFormat:@"%@", @(p_value)]];
        }
        NSInteger current_p_vlaue = [[[_configValueHash objectForKey:@"boll_value"] objectForKey:@"p"] integerValue];
        current_index = current_p_vlaue - p_value_min;
    }
    
    //  show
    ViewSimulateActionSheet* sheet = [ViewSimulateActionSheet styleDefault];
    sheet.tag = row;
    sheet.custom_tag = @"boll";
    sheet.pickerView.tag = row;
    sheet.delegate = self;
    //  selected
    [sheet selectRow:current_index inComponent:0 animated:NO];
    [sheet showInView:self.navigationController.view];
}

- (void)_onMacdFieldClicked:(NSInteger)row
{
    //  data source
    [_pickerDataArray removeAllObjects];
    
    NSInteger current_index = 0;
    
    if (row == 1){
        //  select short
        NSInteger value_min = 2;
        NSInteger value_max = 90;
        for (NSInteger value = value_min; value <= value_max; ++value) {
            [_pickerDataArray addObject:[NSString stringWithFormat:@"%@", @(value)]];
        }
        NSInteger current_vlaue = [[[_configValueHash objectForKey:@"macd_value"] objectForKey:@"s"] integerValue];
        current_index = current_vlaue - value_min;
    }else if (row == 2){
        //  select long
        NSInteger value_min = 2;
        NSInteger value_max = 90;
        for (NSInteger value = value_min; value <= value_max; ++value) {
            [_pickerDataArray addObject:[NSString stringWithFormat:@"%@", @(value)]];
        }
        NSInteger current_vlaue = [[[_configValueHash objectForKey:@"macd_value"] objectForKey:@"l"] integerValue];
        current_index = current_vlaue - value_min;
    }else{
        //  select dea N
        NSInteger value_min = 2;
        NSInteger value_max = 90;
        for (NSInteger value = value_min; value <= value_max; ++value) {
            [_pickerDataArray addObject:[NSString stringWithFormat:@"%@", @(value)]];
        }
        NSInteger current_vlaue = [[[_configValueHash objectForKey:@"macd_value"] objectForKey:@"m"] integerValue];
        current_index = current_vlaue - value_min;
    }
    
    //  show
    ViewSimulateActionSheet* sheet = [ViewSimulateActionSheet styleDefault];
    sheet.tag = row;
    sheet.custom_tag = @"macd";
    sheet.pickerView.tag = row;
    sheet.delegate = self;
    //  selected
    [sheet selectRow:current_index inComponent:0 animated:NO];
    [sheet showInView:self.navigationController.view];
}

-(void)actionCancle:(ViewSimulateActionSheet*)sheet
{
    [sheet dismissWithCompletion:^{
    }];
}

-(void)actionDone:(ViewSimulateActionSheet*)sheet
{
    [sheet dismissWithCompletion:^{
        NSInteger selected_value = [[_pickerDataArray objectAtIndex:[sheet selectedRowInComponent:0]] integerValue];
        id index_type = sheet.custom_tag;
        assert(index_type);
        if ([index_type isEqualToString:@"ma"]){
            NSMutableArray* ma_value_ary = [_configValueHash objectForKey:@"ma_value"];
            ma_value_ary[sheet.tag - 1] = @(selected_value);
        }else if ([index_type isEqualToString:@"ema"]){
            NSMutableArray* ema_value_ary = [_configValueHash objectForKey:@"ema_value"];
            ema_value_ary[sheet.tag - 1] = @(selected_value);
        }else if ([index_type isEqualToString:@"boll"]){
            NSMutableDictionary* boll_value_hash = [_configValueHash objectForKey:@"boll_value"];
            if (sheet.tag == 1){
                [boll_value_hash setObject:@(selected_value) forKey:@"n"];
            }else{
                [boll_value_hash setObject:@(selected_value) forKey:@"p"];
            }
        }else if ([index_type isEqualToString:@"macd"]){
            NSMutableDictionary* macd_value_hash = [_configValueHash objectForKey:@"macd_value"];
            if (sheet.tag == 1){
                [macd_value_hash setObject:@(selected_value) forKey:@"s"];
            }else if (sheet.tag == 2){
                [macd_value_hash setObject:@(selected_value) forKey:@"l"];
            }else{
                [macd_value_hash setObject:@(selected_value) forKey:@"m"];
            }
        }else{
            assert(false);
        }
        [_mainTableView reloadData];
    }];
}

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return [_pickerDataArray count];
}

//- (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component __TVOS_PROHIBITED
//{
//    return [_pickerDataArray objectAtIndex:row];
//}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(nullable UIView *)view __TVOS_PROHIBITED
{
    for (UIView* subView in pickerView.subviews) {
        if (subView.frame.size.height <= 1.0f){
            subView.backgroundColor = [ThemeManager sharedThemeManager].bottomLineColor;
        }
    }
    
    UILabel* label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    if ([[_pickerDataArray objectAtIndex:row] integerValue] == 0){
        label.text = NSLocalizedString(@"kKlineIndexCellHide", @"不显示");
    }else{
        label.text = [_pickerDataArray objectAtIndex:row];
    }
    label.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    return label;
}

@end
