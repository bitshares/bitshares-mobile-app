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

- (WsPromise*)_onSelectNumberFromRange:(NSString*)title
                                   bgn:(NSInteger)bgn
                                   end:(NSInteger)end
                          currentValue:(NSInteger)currentValue
{
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        NSMutableArray* data_list = [NSMutableArray array];
        NSInteger default_select = -1;
        for (NSInteger i = bgn; i <= end; ++i) {
            id name;
            if (i == 0){
                name = NSLocalizedString(@"kKlineIndexCellHide", @"不显示");
            }else{
                name = [NSString stringWithFormat:@"%@", @(i)];
            }
            if (i == currentValue){
                default_select = [data_list count];
            }
            [data_list addObject:@{@"name":name, @"value":@(i)}];
        }
        [[[MyPopviewManager sharedMyPopviewManager] showModernListView:self.navigationController
                                                               message:title
                                                                 items:data_list
                                                               itemkey:@"name"
                                                          defaultIndex:default_select] then:(^id(id result) {
            if (result){
                resolve(@([[result objectForKey:@"value"] integerValue]));
            }else{
                resolve(nil);
            }
            return nil;
        })];
    }];
}

- (void)_onMaFieldClicked:(NSInteger)row
{
    NSMutableArray* ma_value = [_configValueHash objectForKey:@"ma_value"];
    [[self _onSelectNumberFromRange:[NSString stringWithFormat:@"MA%@", @(row)]
                                bgn:0 end:120
                       currentValue:[[ma_value objectAtIndex:row - 1] integerValue]] then:(^id(id selected_value) {
        if (selected_value){
            ma_value[row - 1] = selected_value;
            [_mainTableView reloadData];
        }
        return nil;
    })];
}

- (void)_onEmaFieldClicked:(NSInteger)row
{
    NSMutableArray* ema_value = [_configValueHash objectForKey:@"ema_value"];
    [[self _onSelectNumberFromRange:[NSString stringWithFormat:@"EMA%@", @(row)]
                                bgn:0 end:120
                       currentValue:[[ema_value objectAtIndex:row - 1] integerValue]] then:(^id(id selected_value) {
        if (selected_value){
            ema_value[row - 1] = selected_value;
            [_mainTableView reloadData];
        }
        return nil;
    })];
}

- (void)_onBollFieldClicked:(NSInteger)row
{
    NSInteger bgn;
    NSInteger end;
    NSString* key;
    NSString* title;
    if (row == 1){
        bgn = 1;
        end = 120;
        key = @"n";
        title = NSLocalizedString(@"kKlineIndexCellBollN", @"BOLL N");
    }else{
        bgn = 1;
        end = 9;
        key = @"p";
        title = NSLocalizedString(@"kKlineIndexCellBollP", @"BOLL P");
    }
    
    NSMutableDictionary* boll_value = [_configValueHash objectForKey:@"boll_value"];
    [[self _onSelectNumberFromRange:title
                                bgn:bgn end:end
                       currentValue:[[boll_value objectForKey:key] integerValue]] then:(^id(id selected_value) {
        if (selected_value){
            [boll_value setObject:selected_value forKey:key];
            [_mainTableView reloadData];
        }
        return nil;
    })];
}

- (void)_onMacdFieldClicked:(NSInteger)row
{
    NSString* key;
    NSString* title;
    switch (row) {
        case 1:
        {
            key = @"s";
            title = NSLocalizedString(@"kKlineIndexCellMacdS", @"MACD S");
        }
            break;
        case 2:
        {
            key = @"l";
            title = NSLocalizedString(@"kKlineIndexCellMacdL", @"MACD L");
        }
            break;
        case 3:
        {
            key = @"m";
            title = NSLocalizedString(@"kKlineIndexCellMacdM", @"MACD M");
        }
            break;
        default:
            assert(NO);
            break;
    }
    NSMutableDictionary* macd_value = [_configValueHash objectForKey:@"macd_value"];
    [[self _onSelectNumberFromRange:title
                                bgn:2 end:120
                       currentValue:[[macd_value objectForKey:key] integerValue]] then:(^id(id selected_value) {
        if (selected_value){
            [macd_value setObject:selected_value forKey:key];
            [_mainTableView reloadData];
        }
        return nil;
    })];
}

@end
