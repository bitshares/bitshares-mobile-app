//
//  VCAssetInfos.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetInfos.h"

#import "VCCallOrderRanking.h"
#import "VCFeedPriceDetail.h"
#import "VCSettlementOrders.h"

#import "VCSearchNetwork.h"

@interface VCAssetInfos ()
{
    NSDictionary*   _currAsset;
}

@end

@implementation VCAssetInfos

-(void)dealloc
{
    _currAsset = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        //  初始化默认资产
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        id list = [chainMgr getMainSmartAssetList];
        assert(list && [list count] > 0);
        _currAsset = [chainMgr getAssetBySymbol:[list firstObject]];
    }
    return self;
}

- (NSArray*)getTitleStringArray
{
    return @[
        NSLocalizedString(@"kVcSmartPageTitleRank", @"抵押排行"),
        NSLocalizedString(@"kVcSmartPageTitleFeed", @"喂价详情"),
        NSLocalizedString(@"kVcOrderPageSettleOrders", @"清算单")
    ];
}

- (NSArray*)getSubPageVCArray
{
    return @[
        [[VCRankingList alloc] initWithOwner:self asset:_currAsset],
        [[VCFeedPriceDetailSubPage alloc] initWithOwner:self asset:_currAsset],
        [[VCSettlementOrders alloc] initWithOwner:self tradingPair:[self genSettlementOrderTradingPair:_currAsset] fullAccountInfo:nil]
    ];
}

- (TradingPair*)genSettlementOrderTradingPair:(id)curr_asset
{
    //  REMARK：构造清算单界面所需 *TradingPair* 参数。
    //  注：这里构造的并非完整的 TradingPair 对象，清算单界面目前只需要 baseAsset 和 smartAssetId 两个数据，这里只确保这两个参数正确。
    TradingPair* tradingPair = [[TradingPair alloc] initWithBaseAsset:curr_asset quoteAsset:curr_asset];
    tradingPair.smartAssetId = [curr_asset objectForKey:@"id"];
    tradingPair.sbaAssetId = [curr_asset objectForKey:@"id"];
    tradingPair.isCoreMarket = YES;
    return tradingPair;
}

- (void)onRightButtonClicked
{
    NSMutableArray* asset_list = [NSMutableArray array];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    for (id symbol in [chainMgr getMainSmartAssetList]) {
        [asset_list addObject:[chainMgr getAssetBySymbol:symbol]];
    }
    [asset_list addObject:@{@"symbol":NSLocalizedString(@"kVcAssetMgrCellValueSmartBackingAssetCustom", @"自定义"), @"is_custom":@YES}];
    [VcUtils showPicker:self selectAsset:asset_list title:nil
               callback:^(id selectItem) {
        if ([[selectItem objectForKey:@"is_custom"] boolValue]) {
            VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetSmart callback:^(id asset_info) {
                if (asset_info){
                    [self processSelectNewAsset:asset_info];
                }
            }];
            [self pushViewController:vc
                             vctitle:NSLocalizedString(@"kVcTitleSearchAssets", @"搜索资产")
                           backtitle:kVcDefaultBackTitleName];
        } else {
            [self processSelectNewAsset:selectItem];
        }
    }];
}

- (void)processSelectNewAsset:(id)newAsset
{
    //  选择的就是当前资产，直接返回。
    if ([[newAsset objectForKey:@"id"] isEqualToString:_currAsset[@"id"]]){
        return;
    }
    
    //  更新缓存
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [chainMgr appendAssetCore:newAsset];
    
    //  更新资产
    _currAsset = newAsset;
    for (VCBase* vc in _subvcArrays) {
        if ([vc respondsToSelector:@selector(setCurrent_asset:)]) {
            [vc performSelector:@selector(setCurrent_asset:) withObject:_currAsset];
        } else if ([vc respondsToSelector:@selector(setTradingPair:)]) {
            [vc performSelector:@selector(setTradingPair:) withObject:[self genSettlementOrderTradingPair:_currAsset]];
        }
    }
    
    //  刷新当前页面
    [[self currentPage] onControllerPageChanged];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    [self showRightButton:NSLocalizedString(@"kDebtLableSelectAsset", @"选择资产") action:@selector(onRightButtonClicked)];
    
    //  REMARK：请求第一页数据
    [[self currentPage] onControllerPageChanged];
}

@end

