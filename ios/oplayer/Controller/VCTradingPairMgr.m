//
//  VCTradingPairMgr.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTradingPairMgr.h"
#import "VCSearchNetwork.h"

#import "ViewQuoteBasePairCell.h"
#import "ViewMyPairsCell.h"
#import "ViewEmptyInfoCell.h"

enum
{
    kVcSecPair = 0,         //  PAIR信息CELL
    kVcSecSubmit,           //  提交按钮
    kVcSecList,             //  已有的列表
    
    kvcSecMax
};

enum
{
    kTailerTagAssetName = 1,
    kTailerTagSpace,
    kTailerTagBtnAll
};

@interface VCTradingPairMgr ()
{
    NSMutableDictionary*    _args_pair_info;
    NSMutableArray*         _data_array_pairs;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _lbCommit;
    ViewEmptyInfoCell*      _cellNoPairs;
}

@end

@implementation VCTradingPairMgr

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbCommit = nil;
    _cellNoPairs = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        _args_pair_info = [NSMutableDictionary dictionary];
        _data_array_pairs = [NSMutableArray array];
        //  获取所有收藏或自定义交易对列表。
        [_data_array_pairs addObjectsFromArray:[[[AppCacheManager sharedAppCacheManager] get_all_fav_markets] allValues]];
        [_data_array_pairs sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [[obj1 objectForKey:@"base"] compare:[obj2 objectForKey:@"base"]];
        }];
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 按钮
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kLabelBtnNameAddPair", @"添加")];
    
    //  UI - 空列表
    _cellNoPairs = [[ViewEmptyInfoCell alloc] initWithText:NSLocalizedString(@"kLabelNoFavMarket", @"没有任何自选") iconName:nil];
    _cellNoPairs.hideTopLine = YES;
    _cellNoPairs.hideBottomLine = YES;
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecList) {
        if ([_data_array_pairs count] <= 0) {
            //  empty cell
            return 1;
        } else {
            return [_data_array_pairs count];
        }
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecPair:
            return 72.0f;
        case kVcSecList:
            if ([_data_array_pairs count] <= 0){
                //  Empty Cell
                return 60.0f;
            }else{
                return tableView.rowHeight;
            }
            break;
        default:
            break;
    }
    return tableView.rowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == kVcSecList){
        return 48.0f;
    }else{
        return 0.01f;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == kVcSecList){
        CGFloat fWidth = self.view.bounds.size.width;
        CGFloat xOffset = tableView.layoutMargins.left;
        UIView* myView = [[UIView alloc] init];
        myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 48.0f)];
        titleLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:16];
        titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kSearchTipsMyCustomPairs", @"我的交易对(%@个)"),
                           @([_data_array_pairs count])];
        [myView addSubview:titleLabel];
        
        //        UIButton* allOrderButton = [UIButton buttonWithType:UIButtonTypeCustom];
        //        allOrderButton.frame = CGRectMake(fWidth - xOffset - 120, 0, 120, 64);
        //        allOrderButton.backgroundColor = [UIColor clearColor];
        //        [allOrderButton setTitle:@"同步" forState:UIControlStateNormal];
        //        [allOrderButton setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
        //        allOrderButton.titleLabel.font = [UIFont systemFontOfSize:16.0];
        //        allOrderButton.userInteractionEnabled = YES;
        //        allOrderButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        ////        [allOrderButton addTarget:self action:@selector(onAllOrderButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        //        [myView addSubview:allOrderButton];
        
        return myView;
    }else{
        return [[UIView alloc] init];
    }
}

- (void)onButtonFavClicked:(UIButton*)sender
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    id fav_item = [_data_array_pairs objectAtIndex:sender.tag];
    id quote = [chainMgr getChainObjectByID:fav_item[@"quote"]];
    id base = [chainMgr getChainObjectByID:fav_item[@"base"]];
    
    if ([VcUtils processMyFavPairStateChanged:quote base:base associated_view:nil]) {
        //  刷新界面。
        [_mainTableView reloadData];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecPair:
        {
            ViewQuoteBasePairCell* cell = [[ViewQuoteBasePairCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                                       reuseIdentifier:nil
                                                                                    vc:self];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            [cell setItem:_args_pair_info];
            return cell;
        }
            break;
        case kVcSecSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcSecList:
        {
            if ([_data_array_pairs count] <= 0) {
                //  empty cell
                return _cellNoPairs;
            } else {
                
                ViewMyPairsCell* cell = [[ViewMyPairsCell alloc] init];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.backgroundColor = [UIColor clearColor];
                cell.showCustomBottomLine = YES;
                
                id item = [_data_array_pairs objectAtIndex:indexPath.row];
                [cell setItem:item];
                
                //  收藏/取消收藏 按钮
                UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
                UIImage* image = [UIImage templateImageNamed:@"iconFav"];
                [btn setBackgroundImage:image forState:UIControlStateNormal];
                btn.frame = CGRectMake(0, 0, image.size.width, image.size.height);
                btn.userInteractionEnabled = YES;
                btn.tag = indexPath.row;
                [btn addTarget:self action:@selector(onButtonFavClicked:) forControlEvents:UIControlEventTouchUpInside];
                if ([[AppCacheManager sharedAppCacheManager] is_fav_market:[item objectForKey:@"quote"] base:[item objectForKey:@"base"]]) {
                    btn.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
                } else {
                    btn.tintColor = [ThemeManager sharedThemeManager].textColorGray;
                }
                cell.accessoryView = btn;
                
                return cell;
            }
        }
            break;
        default:
            break;
    }
    //  not reached.
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kVcSecSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}


- (void)onSubmitClicked
{
    assert(_args_pair_info);
    
    id quote = [_args_pair_info objectForKey:@"quote"];
    id base = [_args_pair_info objectForKey:@"base"];
    
    if (!quote) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcMyPairSubmitTipMissQuoteAsset", @"请选择交易资产。")];
        return;
    }
    
    if (!base) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcMyPairSubmitTipMissBaseAsset", @"请选择报价资产。")];
        return;
    }
    
    if ([[quote objectForKey:@"id"] isEqualToString:[base objectForKey:@"id"]]) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcMyPairSubmitTipQuoteBaseIsSame", @"交易资产和报价资产不能相同。")];
        return;
    }
    
    //  添加
    [self onAddPairCore:quote base:base];
}

- (void)onAddPairCore:(id)quote base:(id)base
{
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    
    NSString* quote_id = [quote objectForKey:@"id"];
    NSString* base_id = [base objectForKey:@"id"];
    if ([pAppCache is_fav_market:quote_id base:base_id]) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcMyPairSubmitTipPairIsAlreadyExist", @"该交易对已存在。")];
        return;
    }
    
    if ([VcUtils processMyFavPairStateChanged:quote base:base associated_view:nil]) {
        //  添加到列表
        BOOL exist = NO;
        for (id fav_item in _data_array_pairs) {
            if ([quote_id isEqualToString:[fav_item objectForKey:@"quote"]] &&
                [base_id isEqualToString:[fav_item objectForKey:@"base"]]) {
                exist = YES;
                break;
            }
        }
        if (!exist) {
            [_data_array_pairs addObject:@{@"base":base_id, @"quote":quote_id}];
            [_data_array_pairs sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                return [[obj1 objectForKey:@"base"] compare:[obj2 objectForKey:@"base"]];
            }];
        }
        [_mainTableView reloadData];
    }
}

#pragma mark- for actions

- (void)onButtonClicked_Quote
{
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
        if (asset_info){
            [[ChainObjectManager sharedChainObjectManager] appendAssetCore:asset_info];
            [_args_pair_info setObject:asset_info forKey:@"quote"];
            [_mainTableView reloadData];
        }
    }];
    [self pushViewController:vc
                     vctitle:NSLocalizedString(@"kVcTitleSearchAssetQuote", @"搜索交易资产")
                   backtitle:kVcDefaultBackTitleName];
}

- (void)onButtonClicked_Base
{
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
        if (asset_info){
            [[ChainObjectManager sharedChainObjectManager] appendAssetCore:asset_info];
            [_args_pair_info setObject:asset_info forKey:@"base"];
            [_mainTableView reloadData];
        }
    }];
    [self pushViewController:vc
                     vctitle:NSLocalizedString(@"kVcTitleSearchAssetBase", @"搜索报价资产")
                   backtitle:kVcDefaultBackTitleName];
}

- (void)onButtonClicked_Switched:(UIButton*)sender
{
    assert(_args_pair_info);
    
    id quote = [_args_pair_info objectForKey:@"quote"];
    id base = [_args_pair_info objectForKey:@"base"];
    
    if (quote) {
        [_args_pair_info setObject:quote forKey:@"base"];
    } else {
        [_args_pair_info removeObjectForKey:@"base"];
    }
    
    if (base) {
        [_args_pair_info setObject:base forKey:@"quote"];
    } else {
        [_args_pair_info removeObjectForKey:@"quote"];
    }
    
    //  刷新列表
    [_mainTableView reloadData];
}

@end
