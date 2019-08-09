//
//  ChainObjectManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "ChainObjectManager.h"
#import "OrgUtils.h"

#import "AppCommon.h"
#import "ThemeManager.h"
#import "BitsharesClientManager.h"
#import "GrapheneConnectionManager.h"
#import "TradingPair.h"
#import "WalletManager.h"
#import "SettingManager.h"

#include "bts_wallet_core.h"

static ChainObjectManager *_sharedChainObjectManager = nil;

@interface ChainObjectManager()
{
    NSMutableDictionary*    _cacheAssetSymbol2ObjectHash;   //  内存缓存
    NSMutableDictionary*    _cacheObjectID2ObjectHash;      //  内存缓存
    NSMutableDictionary*    _cacheAccountName2ObjectHash;   //  内存缓存
    NSMutableDictionary*    _cacheUserFullAccountData;      //  内存缓存 - 用户完整信息（每次查询后更新。）
    NSMutableDictionary*    _cacheVoteIdInfoHash;           //  内存缓存
    
    NSDictionary*           _defaultMarketInfos;            //  ipa自带的默认配置信息（fowallet_config.json）
    NSMutableDictionary*    _defaultMarketPairs;            //  默认内置交易对。交易对格式：#{base_symbol}_#{quote_symbol}
    NSMutableDictionary*    _defaultMarketBaseHash;         //  默认内置市场的 Hash 格式。base_symbol => market_info
    
    NSArray*                _defaultGroupList;              //  默认分组信息列表（按照id升序列排列）
    
    NSMutableDictionary*    _tickerDatas;                   //  行情 ticker 数据 格式：#{base_symbol}_#{quote_symbol} => ticker_data
    
    NSMutableArray*         _mergedMarketInfoList;          //  市场信息列表 默认市场信息的基础上合并了自定义交易对后的市场信息。
    
    NSMutableDictionary*    _estimate_unit_hash;            //  计价单位 Hash 计价货币symbol => {...}
}
@end

@implementation ChainObjectManager

@synthesize isTestNetwork;
@synthesize grapheneChainID;
@synthesize grapheneCoreAssetID, grapheneCoreAssetSymbol, grapheneAddressPrefix;

+(ChainObjectManager *)sharedChainObjectManager
{
    @synchronized(self)
    {
        if(!_sharedChainObjectManager)
        {
            _sharedChainObjectManager = [[ChainObjectManager alloc] init];
        }
        return _sharedChainObjectManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        //  初始化各种属性默认值
        self.isTestNetwork = NO;
        self.grapheneChainID = @BTS_NETWORK_CHAIN_ID;
        self.grapheneCoreAssetID = BTS_NETWORK_CORE_ASSET_ID;
        self.grapheneCoreAssetSymbol = @BTS_NETWORK_CORE_ASSET;
        self.grapheneAddressPrefix = @BTS_ADDRESS_PREFIX;
        
        _cacheAssetSymbol2ObjectHash = [NSMutableDictionary dictionary];
        _cacheObjectID2ObjectHash = [NSMutableDictionary dictionary];
        _cacheAccountName2ObjectHash = [NSMutableDictionary dictionary];
        _cacheUserFullAccountData = [NSMutableDictionary dictionary];
        _cacheVoteIdInfoHash = [NSMutableDictionary dictionary];
        _defaultMarketInfos = nil;
        _defaultMarketPairs = nil;
        _defaultGroupList = nil;
        
        _tickerDatas = [NSMutableDictionary dictionary];
        _mergedMarketInfoList = [NSMutableArray array];
        _estimate_unit_hash = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc
{
    _cacheAssetSymbol2ObjectHash = nil;
    _cacheObjectID2ObjectHash = nil;
    _cacheAccountName2ObjectHash = nil;
    _cacheUserFullAccountData = nil;
    _cacheVoteIdInfoHash = nil;
    
    _tickerDatas = nil;
    _mergedMarketInfoList = nil;
}

/**
 *  (public) 启动初始化
 */
- (void)initAll
{
    [self loadDefaultMarketInfos];
    [self buildAllMarketsInfos];
}

- (void)loadDefaultMarketInfos
{
    if (_defaultMarketInfos){
        return;
    }
    
    NSString* bundlePath = [NSBundle mainBundle].resourcePath;
    //  正式网络和测试网络加载不同的配置文件。
#if GRAPHENE_BITSHARES_TESTNET
    NSString* fullPathInApp = [NSString stringWithFormat:@"%@/%@/%@", bundlePath, kAppStaticDir, @"fowallet_config_testnet.json"];
#else
    NSString* fullPathInApp = [NSString stringWithFormat:@"%@/%@/%@", bundlePath, kAppStaticDir, @"fowallet_config.json"];
#endif
    NSData* data = [NSData dataWithContentsOfFile:fullPathInApp];
    if (!data){
        return;
    }
    NSString* rawdatajson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!rawdatajson){
        return;
    }
    _defaultMarketInfos = [NSJSONSerialization JSONObjectWithData:[rawdatajson dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:NSJSONReadingAllowFragments error:nil];
    assert(_defaultMarketInfos);
    
    //  初始化默认交易对和默认市场Hash
    _defaultMarketPairs = [NSMutableDictionary dictionary];
    _defaultMarketBaseHash = [NSMutableDictionary dictionary];
    for (id market in [_defaultMarketInfos objectForKey:@"markets"]) {
        id base = [market objectForKey:@"base"];
        id base_symbol = [base objectForKey:@"symbol"];
        for (id group in [market objectForKey:@"group_list"]) {
            for (id quote_symbol in [group objectForKey:@"quote_list"]) {
                [_defaultMarketPairs setObject:@YES forKey:[NSString stringWithFormat:@"%@_%@", base_symbol, quote_symbol]];
            }
        }
        _defaultMarketBaseHash[base_symbol] = market;
    }
    
    //  内部资产也添加到资产列表
    [self appendAssets:[_defaultMarketInfos objectForKey:@"internal_assets"]];
    
    //  初始化内部分组信息（并排序）
    _defaultGroupList = [[[self getDefaultGroupInfos] allValues] sortedArrayUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [[obj1 objectForKey:@"id"] compare:[obj2 objectForKey:@"id"]];
    })];
    
    //  初始化计价方式 Hash
    for (id currency in [self getEstimateUnitList]) {
        id symbol = [currency objectForKey:@"symbol"];
        [_estimate_unit_hash setObject:currency forKey:symbol];
    }
    
    //  初始化主题风格列表
    [[ThemeManager sharedThemeManager] initThemeFromConfig:[_defaultMarketInfos objectForKey:@"internal_themes"]];
}

#pragma mark- aux methods
/**
 *  (private) 计算资产所属分组信息（给自定义资产归类）
 */
- (NSDictionary*)auxCalcGroupInfo:(id)quote_asset
{
    assert(_defaultGroupList);
    assert(quote_asset);
    
    id quote_issuer = [quote_asset objectForKey:@"issuer"];
    
    for (id group_info in _defaultGroupList) {
        //  自定义资产都不归纳到主区
        if ([[group_info objectForKey:@"main"] boolValue]){
            continue;
        }
        //  考虑归纳到特定网关里
        if ([[group_info objectForKey:@"gateway"] boolValue]){
            BOOL issuer_matched = [[group_info objectForKey:@"issuer"] ruby_any:(^BOOL(id issuer_account_id) {
                return [issuer_account_id isEqualToString:quote_issuer];
            })];
            //  第一步、资产发行人和网关发行人一致
            if (issuer_matched){
                //  第二步、资产发行人一致的前提下再判断资产的前缀是否和网关前缀一致。（例：WWW网关发行人发了个资产SEER，但是没有WWW.前缀。）
                id group_prefix = [group_info objectForKey:@"prefix"];
                id quote_name = [quote_asset objectForKey:@"symbol"];
                if ([quote_name rangeOfString:group_prefix].location == 0){
                    id ary = [quote_name componentsSeparatedByString:@"."];
                    if ([ary count] >= 2 && [[ary objectAtIndex:0] isEqualToString:group_prefix]){
                        //  匹配：返回对应分组
                        return group_info;
                    }
                }
            }
            continue;
        }
        //  归纳到其他区
        if ([[group_info objectForKey:@"other"] boolValue]){
            return group_info;
        }
    }
    
    //  not reached...
    return nil;
}

/**
 *  (public) 生成所有市场的分组信息（包括内置交易对和自定义交易对）初始化调用、每次添加删除自定义交易对时调用。
 */
- (void)buildAllMarketsInfos
{
    [_mergedMarketInfoList removeAllObjects];
    
    //  获取内置默认市场信息
    id defaultMarkets = [self getDefaultMarketInfos];
    
    //  获取自定义交易对信息 格式参考：#{basesymbol}_#{quotesymbol} => @{@"quote":quote_asset(object),@"base":base_symbol}
    id custom_markets = [[AppCacheManager sharedAppCacheManager] get_all_custom_markets];
    if ([custom_markets count] <= 0){
        [_mergedMarketInfoList addObjectsFromArray:defaultMarkets];
        return;
    }
    
    //  开始合并
    NSMutableDictionary* market_hash = [NSMutableDictionary dictionary];
    for (id market in defaultMarkets) {
        id base_symbol = market[@"base"][@"symbol"];
        //  REMARK：克隆后的对象是 mutable 的对象。
        id new_market = [OrgUtils deepClone:market];
        market_hash[base_symbol] = new_market;
        [_mergedMarketInfoList addObject:new_market];
    }
    
    //  循环所有自定义交易对，分别添加到对应分组里。
    for (id pair in custom_markets) {
        id info = custom_markets[pair];
        id base_symbol = info[@"base"];
        //  base_symbol 决定分在哪个大的 market 里。
        id target_market = [market_hash objectForKey:base_symbol];
        if (!target_market){
            continue;   //  REMARK：已经删除掉的市场。比如添加了 CNC，用户自定义之后又删除了 CNC 市场。
        }
        //  quote 决定分在哪个 group 里。
        id quote_asset = info[@"quote"];
        id quote_symbol = [quote_asset objectForKey:@"symbol"];
        if ([quote_symbol isEqualToString:base_symbol]){
            continue;   //  不应该出现
        }
        
        //  添加资产
        [self appendAssetCore:quote_asset];
        
        //  计算 asset 所属分组
        id target_group_info = [self auxCalcGroupInfo:quote_asset];
        assert(target_group_info);
        
        //  从当前市场获取该分组信息
        NSInteger target_group_info_id = [[target_group_info objectForKey:@"id"] integerValue];
        id matched_group_info = [target_market[@"group_list"] ruby_find:(^BOOL(id src) {
            id group_info_02 = [self getGroupInfoFromGroupKey:src[@"group_key"]];
            return [[group_info_02 objectForKey:@"id"] integerValue] == target_group_info_id;
        })];
        
        //  当前市场存在该分组，只直接添加到该分组里。否则新建一个分组，并把该分组信息添加到市场分组列表。
        if (matched_group_info){
            [[matched_group_info objectForKey:@"quote_list"] addObject:quote_symbol];
        }else{
            matched_group_info = @{@"group_key":target_group_info[@"key"], @"quote_list":[NSMutableArray arrayWithObject:quote_symbol]};
            [target_market[@"group_list"] addObject:matched_group_info];
        }
    }
    
    //  重新排序下每个市场下的分组顺序
    for (id market in _mergedMarketInfoList) {
        [market[@"group_list"] sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            id group01 = [self getGroupInfoFromGroupKey:obj1[@"group_key"]];
            id group02 = [self getGroupInfoFromGroupKey:obj2[@"group_key"]];
            return [[group01 objectForKey:@"id"] compare:[group02 objectForKey:@"id"]];
        })];
    }
}

/**
 *  (public) 获取部分默认配置参数
 */
- (NSDictionary*)getDefaultParameters
{
    assert(_defaultMarketInfos);
    return [_defaultMarketInfos objectForKey:@"parameters"];
}

/**
 *  (public) 获取水龙头部分配置参数
 */
- (NSDictionary*)getDefaultFaucet
{
    assert(_defaultMarketInfos);
    return [_defaultMarketInfos objectForKey:@"faucet"];
}

/**
 * (public) 获取最后选用的水龙头注册地址
 */
- (NSString*)getFinalFaucetURL
{
    //  1、优先从服务器动态获取
    id serverConfig = [SettingManager sharedSettingManager].serverConfig;
    if (serverConfig){
        id serverFaucetURL = [serverConfig objectForKey:@"faucetURL"] ?: @"";
        if (![serverFaucetURL isEqualToString:@""]){
            return serverFaucetURL;
        }
    }
    //  2、其次获取app内默认配置  REMARK: url必须以 / 符号结尾。
    id baseURL = [[self getDefaultFaucet] objectForKey:@"url"];
    return [NSString stringWithFormat:@"%@register", baseURL];
}

/**
 *  (public) 获取抵押排行榜配置列表
 */
- (NSArray*)getCallOrderRankingSymbolList
{
    assert(_defaultMarketInfos);
    return [_defaultMarketInfos objectForKey:@"call_order_ranking_list"];
}

/**
 *  (public) 获取可借贷的资产配置列表
 */
- (NSArray*)getDebtAssetList
{
    assert(_defaultMarketInfos);
    return [_defaultMarketInfos objectForKey:@"debt_asset_list"];
}

/**
 *  (public) 获取手续费列表（按照列表优先选择）
 */
- (NSArray*)getFeeAssetSymbolList
{
    assert(_defaultMarketInfos);
    return [_defaultMarketInfos objectForKey:@"fee_assets_list"];
}

/**
 *  (public) 获取支持的记账单位列表
 */
- (NSArray*)getEstimateUnitList
{
    assert(_defaultMarketInfos);
    return [_defaultMarketInfos objectForKey:@"estimate_unit"];
}

/**
 *  (public) 根据计价货币symbol获取计价单位配置信息
 */
- (NSDictionary*)getEstimateUnitBySymbol:(NSString*)symbol
{
    assert(_estimate_unit_hash);
    assert(symbol);
    return [_estimate_unit_hash objectForKey:symbol];
}

/**
 *  (public) 获取网络配置信息
 */
- (NSDictionary*)getCfgNetWorkInfos
{
    assert(_defaultMarketInfos);
    return [_defaultMarketInfos objectForKey:@"network_infos"];
}

/**
 *  (public) 获取资产作为交易对中的 base 资产的优先级，两者之中，优先级高的作为 base，另外一个作为 quote。
 */
- (NSDictionary*)genAssetBasePriorityHash
{
    NSMutableDictionary* asset_base_priority = [NSMutableDictionary dictionary];
    NSInteger max_priority = 1000;
    //  REMARK：优先级 从 CNY 到 BTS 逐渐降低，其他非市场 base 的资产优先级默认为 0。
    for (id market in [self getDefaultMarketInfos]) {
        id symbol = [[market objectForKey:@"base"] objectForKey:@"symbol"];
        [asset_base_priority setObject:@(max_priority) forKey:symbol];
        max_priority -= 1;
    }
    return [asset_base_priority copy];
}

/**
 *  (public) 获取最终的市场列表信息（默认 + 自定义）
 */
- (NSArray*)getMergedMarketInfos
{
    assert(_mergedMarketInfoList);
    return _mergedMarketInfoList;
}

/**
 *  (public) 获取默认的 markets 列表信息
 */
- (NSArray*)getDefaultMarketInfos
{
    assert(_defaultMarketInfos);
    return [_defaultMarketInfos objectForKey:@"markets"];
}

/**
 *  (public) 根据 base_symbol 获取 market 信息。
 */
- (NSDictionary*)getDefaultMarketInfoByBaseSymbol:(NSString*)base_symbol
{
    assert(_defaultMarketBaseHash);
    return [_defaultMarketBaseHash objectForKey:base_symbol];
}

/**
 *  (public) 获取默认所有的分组信息
 */
- (NSDictionary*)getDefaultGroupInfos
{
    assert(_defaultMarketInfos);
    return [_defaultMarketInfos objectForKey:@"internal_groups"];
}

/**
 *  (public) 获取 or 更新全局属性信息（包括活跃理事会、活跃见证人、手续费等信息）REMARK：该对象ID固定为 2.0.0。
 */
- (NSDictionary*)getObjectGlobalProperties
{
    return [_cacheObjectID2ObjectHash objectForKey:BTS_GLOBAL_PROPERTIES_ID];
}

- (void)updateObjectGlobalProperties:(NSDictionary*)gp
{
    if (gp){
        [_cacheObjectID2ObjectHash setObject:gp forKey:BTS_GLOBAL_PROPERTIES_ID];
    }
}

- (WsPromise*)queryGlobalProperties
{
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    return [[api exec:@"get_global_properties" params:@[]] then:(^id(id global_data) {
        [self updateObjectGlobalProperties:global_data];
        return global_data;
    })];
}

/**
 *  (public) 获取指定分组信息
 */
- (NSDictionary*)getGroupInfoFromGroupKey:(NSString*)group_key
{
    assert(group_key);
    return [[self getDefaultGroupInfos] objectForKey:group_key];
}

/**
 *  (public) 是否是内置交易对判断
 */
- (BOOL)isDefaultPair:(id)quote base:(id)base
{
    NSString* pair = [NSString stringWithFormat:@"%@_%@", [base objectForKey:@"symbol"], [quote objectForKey:@"symbol"]];
    return [[_defaultMarketPairs objectForKey:pair] boolValue];
}
- (BOOL)isDefaultPair:(NSString*)base_symbol quote:(id)quote
{
    NSString* pair = [NSString stringWithFormat:@"%@_%@", base_symbol, [quote objectForKey:@"symbol"]];
    return [[_defaultMarketPairs objectForKey:pair] boolValue];
}
- (BOOL)isDefaultPair:(NSString*)base_symbol quote_symbol:(NSString*)quote_symbol
{
    NSString* pair = [NSString stringWithFormat:@"%@_%@", base_symbol, quote_symbol];
    return [[_defaultMarketPairs objectForKey:pair] boolValue];
}

/**
 *  根据名字、符号、ID等获取各种区块链对象。
 */
- (id)getAssetBySymbol:(NSString*)symbol
{
    assert(_cacheAssetSymbol2ObjectHash);
    assert(symbol);
    return [_cacheAssetSymbol2ObjectHash objectForKey:symbol];
}

- (id)getChainObjectByID:(NSString*)oid
{
    return [_cacheObjectID2ObjectHash objectForKey:oid];
}

- (id)getVoteInfoByVoteID:(NSString*)vote_id
{
    return [_cacheVoteIdInfoHash objectForKey:vote_id];
}

- (id)getAccountByName:(NSString*)name
{
    assert(_cacheAccountName2ObjectHash);
    assert(name);
    return [_cacheAccountName2ObjectHash objectForKey:name];
}

- (id)getBlockHeaderInfoByBlockNumber:(id)block_number
{
    id oid = [NSString stringWithFormat:@"100.0.%@", block_number];     //  REMARK：block_num 不是对象ID，特殊处理。
    return [_cacheObjectID2ObjectHash objectForKey:oid];
}

- (id)getFullAccountDataFromCache:(id)account_id_or_name
{
    assert(_cacheUserFullAccountData);
    assert(account_id_or_name);
    return [_cacheUserFullAccountData objectForKey:account_id_or_name];
}

/**
 *  添加资产
 */
- (void)appendAssets:(NSDictionary*)assets_name2obj_hash
{
    for (NSString* name in assets_name2obj_hash) {
        id obj = [assets_name2obj_hash objectForKey:name];
        [self appendAssetCore:obj];
    }
}

//  (private) 添加到内存 cache
- (void)appendAssetCore:(id)asset
{
    assert(asset);
    
    [_cacheObjectID2ObjectHash setObject:asset forKey:asset[@"id"]];         //  1.3.0格式
    [_cacheAssetSymbol2ObjectHash setObject:asset forKey:asset[@"symbol"]];
}

/**
 *  (public) 更新缓存
 */
- (void)updateGrapheneObjectCache:(NSArray*)data_array
{
    if (data_array && [data_array count] > 0){
        AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
        for (id obj in data_array) {
            id oid = [obj objectForKey:@"id"];
            if (oid){
                [pAppCache update_object_cache:oid object:obj];
                [_cacheObjectID2ObjectHash setObject:obj forKey:oid];
            }
        }
        [pAppCache saveObjectCacheToFile];
    }
}

#pragma mark- aux method
/**
 *  (public) 获取手续费对象
 *  extra_balance   - key: asset_type   value: balance amount
 */
- (NSDictionary*)getFeeItem:(EBitsharesOperations)op_code full_account_data:(NSDictionary*)full_account_data
{
    return [self getFeeItem:op_code full_account_data:full_account_data extra_balance:nil];
}

- (NSDictionary*)getFeeItem:(EBitsharesOperations)op_code full_account_data:(NSDictionary*)full_account_data extra_balance:(NSDictionary*)extra_balance
{
    if (!full_account_data){
        id wallet_account_info = [[WalletManager sharedWalletManager] getWalletAccountInfo];
        assert(wallet_account_info);
        id account_id = [wallet_account_info objectForKey:@"account"][@"id"];
        full_account_data = [self getFullAccountDataFromCache:account_id];
        if (!full_account_data){
            full_account_data = wallet_account_info;
        }
    }
    return [self estimateFeeObject:op_code full_account_data:full_account_data extra_balance:extra_balance];
}

/**
 *  (public) 评估指定交易操作所需要的手续费信息
 */
- (NSDictionary*)estimateFeeObject:(EBitsharesOperations)op full_account_data:(NSDictionary*)full_account_data
                     extra_balance:(NSDictionary*)extra_balance
{
    assert(full_account_data);
    id balances_hash = [NSMutableDictionary dictionary];
    for (id balance_object in [full_account_data objectForKey:@"balances"]) {
        id asset_type = [balance_object objectForKey:@"asset_type"];
        id balance = [balance_object objectForKey:@"balance"];
        //  合并额外的金额
        if (extra_balance){
            id extra_amount = [extra_balance objectForKey:asset_type];
            if (extra_amount){
                balance = @([balance unsignedLongLongValue] + [extra_amount unsignedLongLongValue]);
            }
        }
        [balances_hash setObject:@{@"asset_id":asset_type, @"amount":balance} forKey:asset_type];
    }
    //  合并
    if (extra_balance){
        for (id asset_type in extra_balance) {
            if (![balances_hash objectForKey:asset_type]){
                id extra_amount = [extra_balance objectForKey:asset_type];
                [balances_hash setObject:@{@"asset_id":asset_type, @"amount":extra_amount} forKey:asset_type];
            }
        }
    }
    return [self estimateFeeObject:op balances:[balances_hash allValues]];
}

- (NSDictionary*)estimateFeeObject:(EBitsharesOperations)op balances:(NSArray*)balance_list
{
    //  TODO:fowallet!!!! 对于需要 price_per_kbyte 的 op 目前尚不支持。
    
    //  REMARK：fee_list的资产更新及时（尽可能在每次进入操作前进行更新、比如交易、转账之前。）
    id fee_list = [self getFeeAssetSymbolList];
    
    //  获取指定操作的默认手续费信息
    id gp = [self getObjectGlobalProperties];
    //  网络初始化失败了。
    if (!gp){
        return nil;
    }
    id current_fees = gp[@"parameters"][@"current_fees"];
    id fee_item = [current_fees[@"parameters"] ruby_find:(^BOOL(id op_array) {
        return [[op_array objectAtIndex:0] integerValue] == op; //  op_array: [0, {"fee"=>10420, "price_per_kbyte"=>5789}]
    })];
    double scale = [current_fees[@"scale"] doubleValue];
    id fee_item_args = [fee_item objectAtIndex:1];
    id fee_amount = [fee_item_args objectForKey:@"fee"];
    id price_per_kbyte = [fee_item_args objectForKey:@"price_per_kbyte"];
    //  TODO:fowallet 转账等操作，默认按照1KB价格评估。
    if (price_per_kbyte){
        fee_amount = @([fee_amount unsignedLongLongValue] + [price_per_kbyte unsignedLongLongValue]);
    }
    unsigned long long bts_fee = [fee_amount unsignedLongLongValue];
    //  手续费缩放系数
    bts_fee = ceil(bts_fee * scale / 10000.0);
    id bts_asset = [self getChainObjectByID:self.grapheneCoreAssetID];
    NSInteger bts_precision = [[bts_asset objectForKey:@"precision"] integerValue];
    double bts_fee_real = [OrgUtils calcAssetRealPrice:@(bts_fee) precision:bts_precision];
    
    //  转换资产列表为 资产Hash。格式：asset_id=>amount
    NSMutableDictionary* balance_hash = [NSMutableDictionary dictionary];
    for (id balance in balance_list) {
        [balance_hash setObject:balance[@"amount"] forKey:balance[@"asset_id"]];
    }
    
    //  循环遍历手续费列表，寻找第一个足够支付手续费的资产。
    for (id fee_symbol in fee_list) {
        id fee_asset = [self getAssetBySymbol:fee_symbol];
        id fee_asset_id = fee_asset[@"id"];
        
        //  该 fee 当前余额
        unsigned long long fee_balance_amount = [[balance_hash objectForKey:fee_asset_id] unsignedLongLongValue];
        
        //  该 fee 是 BTS 还是其他资产分别处理
        if ([fee_asset_id isEqualToString:self.grapheneCoreAssetID]){
            if (fee_balance_amount >= bts_fee){
                //  BTS 足够支付手续费
                //  TODO:fowallet fee_amount 小概率为 nil。
                return @{@"fee_asset_id":fee_asset_id, @"amount":fee_amount, @"amount_real":@(bts_fee_real), @"sufficient":@YES};
            }
        }else{
            //  其他其他没动态资产信息，则不能作为手续费。
            id dynamic_asset_data_id = [fee_asset objectForKey:@"dynamic_asset_data_id"];
            if (!dynamic_asset_data_id || [dynamic_asset_data_id isEqualToString:@""]){
                continue;
            }
            
            //  没有手续费池信息，也不能作为手续费。
            id dynamic_asset_data = [self getChainObjectByID:dynamic_asset_data_id];
            if (!dynamic_asset_data){
                continue;
            }
            
            //  其他资产和 BTS 资产进行兑换
            id core_exchange_rate = [[fee_asset objectForKey:@"options"] objectForKey:@"core_exchange_rate"];
            //  没有 core_exchange_rate 信息，则不能作为手续费。
            if (!core_exchange_rate){
                continue;
            }
            
            id core_base = core_exchange_rate[@"base"];
            id core_quote = core_exchange_rate[@"quote"];
            
            id fee_amount;
            id bts_amount;
            if ([core_base[@"asset_id"] isEqualToString:self.grapheneCoreAssetID]){
                //  rate = quote / base(bts)
                fee_amount = core_quote[@"amount"];
                bts_amount = core_base[@"amount"];
            }else{
                //  rate = base / quote(bts)
                fee_amount = core_base[@"amount"];
                bts_amount = core_quote[@"amount"];
            }
            
            //  bts 数量
            double bts_real = [OrgUtils calcAssetRealPrice:bts_amount precision:bts_precision];
            
            //  fee 数量
            NSInteger fee_precision = [[fee_asset objectForKey:@"precision"] integerValue];
            unsigned long long fee_amount_integer = [fee_amount unsignedLongLongValue];
            double fee_precision_pow = pow(10, fee_precision);
            double fee_real = fee_amount_integer / fee_precision_pow;
            
            //  REMARK：用于 CNY、USD 等兑换 BTS 的比例一直都在更新中，避免在用户操作过程中，兑换比例变化导致手续费不足。这里添加一个系数。
            double final_fee_real = 1.2 * fee_real / bts_real * bts_fee_real;
            
            //  向上取整
            unsigned long long final_fee_amount = (unsigned long long)ceil(final_fee_real * fee_precision_pow);
            
            //  REMARK：这里再把 其他资产的手续费(比如CNY)兑换回 BTS 值，然后判断 CNY 资产的手续费池是否足够。重要！！！
            unsigned long long pool_min_value = ceil(bts_real / fee_real * (final_fee_amount / fee_precision_pow) * scale);
            
            //  手续费池余额不足
            if ([[dynamic_asset_data objectForKey:@"fee_pool"] unsignedLongLongValue] < pool_min_value){
                continue;
            }
            
            //  其他资产手续费足够！！
            if (fee_balance_amount >= final_fee_amount){
                //  CNY、USD等资产足够支付手续费
                return @{@"fee_asset_id":fee_asset_id, @"amount":@(final_fee_amount), @"amount_real":@(final_fee_real), @"sufficient":@YES};
            }
        }
    }
    
    //  默认选择BTS支付、但手续费不足。
    return @{@"fee_asset_id":self.grapheneCoreAssetID, @"amount":fee_amount, @"amount_real":@(bts_fee_real), @"sufficient":@NO};
}

#pragma mark- init graphene network
/**
 *  (public) 石墨烯网络初始化，优先调用。重要。
 */
- (WsPromise*)grapheneNetworkInit
{
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    return [[api exec:@"get_chain_properties" params:@[]] then:(^id(id chain_properties) {
        //  石墨烯网络区块链ID和BTS主网链ID不同，则为测试网络，不判断核心资产名字。因为测试网络资产名字也可能为BTS。
        id chain_id = [chain_properties objectForKey:@"chain_id"];
        if (!chain_id || ![chain_id isEqualToString:@BTS_NETWORK_CHAIN_ID]){
            self.isTestNetwork = YES;
        }else{
            self.isTestNetwork = NO;
        }
        self.grapheneChainID = [chain_id copy];
        if (self.isTestNetwork){
            //  测试网络：继续初始化核心资产信息
            return [[api exec:@"get_config" params:@[]] then:(^id(id graphene_config_data) {
                self.grapheneCoreAssetSymbol = [graphene_config_data objectForKey:@"GRAPHENE_SYMBOL"];
                self.grapheneAddressPrefix = [graphene_config_data objectForKey:@"GRAPHENE_ADDRESS_PREFIX"];
                return @YES;
            })];
        }else{
            //  正式网络：直接返回初始化成功
            return @YES;
        }
    })];
}

#pragma mark- for ticker data
/**
 *  启动 app 时初始化所有市场的 ticker 数据。（包括自定义市场）
 */
- (WsPromise*)marketsInitAllTickerData
{
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
    NSMutableArray* promise_list = [NSMutableArray array];
    NSMutableArray* pairs_list = [NSMutableArray array];
    
    for (NSDictionary* market in [self getMergedMarketInfos]){
        id base_item = [market objectForKey:@"base"];
        id base_name = [base_item objectForKey:@"name"];
        id base_symbol = [base_item objectForKey:@"symbol"];
        id group_list = [market objectForKey:@"group_list"];
        
        for (NSDictionary* group_info in group_list) {
            id quote_list = [group_info objectForKey:@"quote_list"];
            for (NSString* quote_symbol in quote_list) {
                //  REMARK：pair格式：#{base_symbol}_#{quote_symbol}
                [pairs_list addObject:[NSString stringWithFormat:@"%@_%@", base_symbol, quote_symbol]];
                NSLog(@"pairs: %@/%@", quote_symbol, base_name);
                [promise_list addObject:[api exec:@"get_ticker" params:@[base_symbol, quote_symbol]]];
            }
        }
    }
    
    return [[WsPromise all:[promise_list copy]] then:(^id(id data_list) {
        [data_list ruby_each_with_index:(^(id ticker, NSInteger idx) {
            NSString* pair = [pairs_list objectAtIndex:idx];
            [_tickerDatas setObject:ticker forKey:pair];
        })];
        
        //  初始化成功
        return @YES;
    })];
}

/**
 *  查询Ticker数据（参数：base、quote构成的Hash的列表。）
 */
- (WsPromise*)queryTickerDataByBaseQuoteSymbolArray:(NSArray*)base_quote_symbol_array
{
    //  要查询的数据为空，则直接返回。
    if (!base_quote_symbol_array || [base_quote_symbol_array count] <= 0){
        return [WsPromise resolve:@YES];
    }
    
    //  构造交易对进行查询
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    NSMutableArray* promise_list = [NSMutableArray array];
    NSMutableArray* pairs_list = [NSMutableArray array];
    for (id pair_info in base_quote_symbol_array) {
        id base_symbol = pair_info[@"base"];
        id quote_symbol = pair_info[@"quote"];
        //  REMARK：pair格式：#{base_symbol}_#{quote_symbol}
        [pairs_list addObject:[NSString stringWithFormat:@"%@_%@", base_symbol, quote_symbol]];
        [promise_list addObject:[api exec:@"get_ticker" params:@[base_symbol, quote_symbol]]];
    }
    
    //  查询核心
    return [[WsPromise all:[promise_list copy]] then:(^id(id data_list) {
        NSInteger idx = 0;
        for (id ticker in data_list) {
            NSString* pair = [pairs_list objectAtIndex:idx];
            [_tickerDatas setObject:ticker forKey:pair];
            ++idx;
        }
        return @YES;
    })];
}

/**
 *  获取行情的 ticker 数据
 */
- (NSDictionary*)getTickerData:(NSString*)base_symbol quote:(NSString*)quote_symbol
{
    NSString* pair = [NSString stringWithFormat:@"%@_%@", base_symbol, quote_symbol];
    return [_tickerDatas objectForKey:pair];
}
/**
 *  更新 ticker 数据
 */
- (void)updateTickeraData:(NSString*)base_symbol quote:(NSString*)quote_symbol data:(NSDictionary*)ticker
{
    assert(base_symbol);
    assert(quote_symbol);
    if (ticker){
        NSString* pair = [NSString stringWithFormat:@"%@_%@", base_symbol, quote_symbol];
        [_tickerDatas setObject:ticker forKey:pair];
    }
}

- (void)updateTickeraData:(NSString*)pair data:(NSDictionary*)ticker
{
    assert(pair);
    if (ticker){
        [_tickerDatas setObject:ticker forKey:pair];
    }
}

#pragma mark- query blocchain data
/**
 *  (public) 查询手续费资产的详细信息（包括动态信息）
 */
- (WsPromise*)queryFeeAssetListDynamicInfo
{
    NSMutableArray* asset_id_array = [NSMutableArray array];
    for (id fee_symbol in [self getFeeAssetSymbolList]) {
        id fee_asset = [self getAssetBySymbol:fee_symbol];
        id fee_asset_id = fee_asset[@"id"];
        //  BTS 资产作为支付手续费的核心资产，则不用查询，足够即可。
        if ([fee_asset_id isEqualToString:self.grapheneCoreAssetID]){
            continue;
        }
        //  添加到查询列表
        [asset_id_array addObject:fee_asset_id];
    }
    NSLog(@"[Track] queryFeeAssetListDynamicInfo start.");
    //  查询手续费资产信息 REMARK：直接查询网络，跳过缓存。
    return [[self queryAllObjectsInfo:asset_id_array
                       cacheContainer:_cacheAssetSymbol2ObjectHash
                       cacheObjectKey:@"symbol"
                       skipQueryCache:YES
                      skipCacheIdHash:nil] then:(^id(id asset_hash) {
        NSLog(@"[Track] queryFeeAssetListDynamicInfo step01 finish.");
        // 仅有 BTS 可支付手续费，那么这里应该为空了。
        if ([asset_hash count] <= 0){
            return nil;
        }
        id dynamic_id_list = [[asset_hash allValues] ruby_map:(^id(id src) {
            return [src objectForKey:@"dynamic_asset_data_id"];
        })];
        //  查询资产的手续费池信息
        GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
        return [[api exec:@"get_objects" params:@[dynamic_id_list]] then:(^id(id data_array) {
            NSLog(@"[Track] queryFeeAssetListDynamicInfo step02 finish.");
            //  更新内存缓存
            for (id obj in data_array) {
                if ([obj isKindOfClass:[NSNull class]]){
                    continue;
                }
                id oid = [obj objectForKey:@"id"];
                [_cacheObjectID2ObjectHash setObject:obj forKey:oid];   //  add to memory cache: id hash
            }
            return nil;
        })];
    })];
}

/**
 *  (public) 查询智能资产的信息（非智能资产返回nil）
 */
- (WsPromise*)queryShortBackingAssetInfos:(NSArray*)asset_id_list
{
    return [[self queryAllAssetsInfo:asset_id_list] then:(^id(id asset_hash) {
        NSMutableDictionary* asset_bitasset_hash = [NSMutableDictionary dictionary];
        
        NSMutableArray* bitasset_id_list = [NSMutableArray array];
        for (id asset_id in asset_id_list) {
            id asset = [asset_hash objectForKey:asset_id];
            assert(asset);
            id bitasset_data_id = [asset objectForKey:@"bitasset_data_id"];
            if (bitasset_data_id && ![bitasset_data_id isEqualToString:@""]){
                [bitasset_id_list addObject:bitasset_data_id];
                [asset_bitasset_hash setObject:bitasset_data_id forKey:asset_id];
            }
        }
        
        return [[self queryAllGrapheneObjects:bitasset_id_list] then:(^id(id bitasset_hash) {
            
            NSMutableDictionary* sba_hash = [NSMutableDictionary dictionary];
            for (id asset_id in asset_bitasset_hash) {
                id bitasset_data_id = [asset_bitasset_hash objectForKey:asset_id];
                assert(bitasset_data_id);
                id bitasset_data = [bitasset_hash objectForKey:bitasset_data_id];
                id short_backing_asset = [[bitasset_data objectForKey:@"options"] objectForKey:@"short_backing_asset"];
                assert(short_backing_asset);
                [sba_hash setObject:short_backing_asset forKey:asset_id];
            }
            
            return [sba_hash copy];
        })];
    })];
}

/**
 *  (public) 查询所有投票ID信息
 */
- (WsPromise*)queryAllVoteIds:(NSArray*)vote_id_array
{
    //  TODO:分批查询？
    assert([vote_id_array count] < 1000);
    
    NSMutableDictionary* resultHash = [NSMutableDictionary dictionary];
    
    //  要查询的数据为空，则返回空的 Hash。
    if (!vote_id_array || [vote_id_array count] <= 0){
        return [WsPromise resolve:resultHash];
    }
    
    NSMutableArray* queryArray = [NSMutableArray array];
    
    //  从缓存加载
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    NSTimeInterval now_ts = [[NSDate date] timeIntervalSince1970];
    for (NSString* vote_id in vote_id_array) {
        id obj = [pAppCache get_object_cache:vote_id now_ts:now_ts];
        if (obj){
            [_cacheVoteIdInfoHash setObject:obj forKey:vote_id];     //  add to memory cache: id hash
            [resultHash setObject:obj forKey:vote_id];
        }else{
            [queryArray addObject:vote_id];
        }
    }
    //  从缓存获取完毕，直接返回。
    if ([queryArray count] == 0){
        return [WsPromise resolve:resultHash];
    }
    
    //  从网络查询。
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
    return [[api exec:@"lookup_vote_ids" params:@[queryArray]] then:(^id(id data_array) {
        //  更新缓存 和 结果
        for (id obj in data_array) {
            if ([obj isKindOfClass:[NSNull class]]){
                continue;
            }
            id vid = [obj objectForKey:@"vote_id"];
            if (vid){
                [pAppCache update_object_cache:vid object:obj];
                [_cacheVoteIdInfoHash setObject:obj forKey:vid];            //  add to memory cache: id hash
                [resultHash setObject:obj forKey:vid];
            }else{
                id vote_for = [obj objectForKey:@"vote_for"];
                id vote_against = [obj objectForKey:@"vote_against"];
                assert(vote_for && vote_against);
                
                [pAppCache update_object_cache:vote_for object:obj];
                [_cacheVoteIdInfoHash setObject:obj forKey:vote_for];       //  add to memory cache: id hash
                [resultHash setObject:obj forKey:vote_for];
                
                [pAppCache update_object_cache:vote_against object:obj];
                [_cacheVoteIdInfoHash setObject:obj forKey:vote_against];   //  add to memory cache: id hash
                [resultHash setObject:obj forKey:vote_against];
            }
        }
        //  保存缓存
        [pAppCache saveObjectCacheToFile];
        //  返回结果
        return resultHash;
    })];
}

/**
 *  (private) 查询指定对象ID列表的所有对象信息，返回 Hash。 格式：{对象ID=>对象信息, ...}
 *
 *  skipQueryCache - 控制是否查询缓存
 *
 *  REMARK：不处理异常，在外层 VC 逻辑中处理。外部需要 catch 该 promise。
 */
- (WsPromise*)queryAllObjectsInfo:(NSArray*)object_id_array
                   cacheContainer:(NSMutableDictionary*)cache
                   cacheObjectKey:(NSString*)key
                   skipQueryCache:(BOOL)skipQueryCache
                  skipCacheIdHash:(NSDictionary*)skipCacheIdHash
{
    NSMutableDictionary* resultHash = [NSMutableDictionary dictionary];
    
    //  要查询的数据为空，则返回空的 Hash。
    if (!object_id_array || [object_id_array count] <= 0){
        return [WsPromise resolve:resultHash];
    }
    
    NSMutableArray* queryArray = [NSMutableArray array];
    if (skipQueryCache){
        //  忽略缓存：重新查询所有ID
        [queryArray addObjectsFromArray:object_id_array];
    }else{
        //  从缓存加载
        AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
        NSTimeInterval now_ts = [[NSDate date] timeIntervalSince1970];
        for (NSString* object_id in object_id_array) {
            if (skipCacheIdHash && [skipCacheIdHash objectForKey:object_id]){
                //  部分ID跳过缓存
                [queryArray addObject:object_id];
            }else{
                id obj = [pAppCache get_object_cache:object_id now_ts:now_ts];
                if (obj){
                    [_cacheObjectID2ObjectHash setObject:obj forKey:object_id];     //  add to memory cache: id hash
                    if (cache && key){
                        [cache setObject:obj forKey:[obj objectForKey:key]];        //  add to memory cache: key hash
                    }
                    [resultHash setObject:obj forKey:object_id];
                }else{
                    [queryArray addObject:object_id];
                }
            }
        }
        //  从缓存获取完毕，直接返回。
        if ([queryArray count] == 0){
            return [WsPromise resolve:resultHash];
        }
    }

    //  从网络查询。
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
    //  REMARK：get_accounts、get_assets、get_witnesses、get_committee_members 等接口适用。
    return [[api exec:@"get_objects" params:@[queryArray]] then:(^id(id data_array) {
        //  更新缓存 和 结果
        AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
        for (id obj in data_array) {
            if ([obj isKindOfClass:[NSNull class]]){
                continue;
            }
            id oid = [obj objectForKey:@"id"];
            [pAppCache update_object_cache:oid object:obj];
            [_cacheObjectID2ObjectHash setObject:obj forKey:oid];       //  add to memory cache: id hash
            if (cache && key){
                [cache setObject:obj forKey:[obj objectForKey:key]];    //  add to memory cache: key hash
            }
            [resultHash setObject:obj forKey:oid];
        }
        //  保存缓存
        [pAppCache saveObjectCacheToFile];
        //  返回结果
        return resultHash;
    })];
}

- (WsPromise*)queryAllAccountsInfo:(NSArray*)account_id_array
{
    return [self queryAllObjectsInfo:account_id_array
                      cacheContainer:_cacheAccountName2ObjectHash
                      cacheObjectKey:@"name"
                      skipQueryCache:NO
                     skipCacheIdHash:nil];
}

- (WsPromise*)queryAllAssetsInfo:(NSArray*)asset_id_array
{
    return [self queryAllObjectsInfo:asset_id_array
                      cacheContainer:_cacheAssetSymbol2ObjectHash
                      cacheObjectKey:@"symbol"
                      skipQueryCache:NO
                     skipCacheIdHash:nil];
}

- (WsPromise*)queryAllGrapheneObjects:(NSArray*)id_array
{
    return [self queryAllObjectsInfo:id_array
                      cacheContainer:nil
                      cacheObjectKey:nil
                      skipQueryCache:NO
                     skipCacheIdHash:nil];
}

- (WsPromise*)queryAllGrapheneObjectsSkipCache:(NSArray*)id_array
{
    return [self queryAllObjectsInfo:id_array
                      cacheContainer:nil
                      cacheObjectKey:nil
                      skipQueryCache:YES
                     skipCacheIdHash:nil];
}

- (WsPromise*)queryAllGrapheneObjects:(NSArray*)id_array skipCacheIdHash:(NSDictionary*)skipCacheIdHash
{
    return [self queryAllObjectsInfo:id_array
                      cacheContainer:nil
                      cacheObjectKey:nil
                      skipQueryCache:NO
                     skipCacheIdHash:skipCacheIdHash];
}

/**
 *  (public) 查询所有 block_num 的 header 信息，返回 Hash。 格式：{对象ID=>对象信息, ...}
 *
 *  skipQueryCache - 控制是否查询缓存
 *
 *  REMARK：不处理异常，在外层 VC 逻辑中处理。外部需要 catch 该 promise。
 */
- (WsPromise*)queryAllBlockHeaderInfos:(NSArray*)block_num_array skipQueryCache:(BOOL)skipQueryCache
{
    NSMutableDictionary* resultHash = [NSMutableDictionary dictionary];
    
    //  要查询的数据为空，则返回空的 Hash。
    if (!block_num_array || [block_num_array count] <= 0){
        return [WsPromise resolve:resultHash];
    }
    
    NSMutableArray* queryArray = [NSMutableArray array];
    if (skipQueryCache){
        //  忽略缓存：重新查询所有 block_num
        [queryArray addObjectsFromArray:block_num_array];
    }else{
        //  从缓存加载
        AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
        for (id block_num in block_num_array) {
            id oid = [NSString stringWithFormat:@"100.0.%@", block_num];    //  REMARK：block_num 不是对象ID，特殊处理。
            id obj = [pAppCache get_object_cache:oid now_ts:-1];            //  -1 不考虑过期日期
            if (obj){
                [_cacheObjectID2ObjectHash setObject:obj forKey:oid];       //  add to memory cache: id hash
                [resultHash setObject:obj forKey:oid];
            }else{
                [queryArray addObject:block_num];
            }
        }
        //  从缓存获取完毕，直接返回。
        if ([queryArray count] == 0){
            return [WsPromise resolve:resultHash];
        }
    }
    
    //  从网络查询。用 get_block_header_batch 代替 get_block_header 接口。
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    return [[api exec:@"get_block_header_batch" params:@[queryArray]] then:(^id(id data_array) {
        //  更新缓存 和 结果
        AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
        for (id block_header_ary in data_array) {
            id block_num = block_header_ary[0];
            id block_header = block_header_ary[1];
            id oid = [NSString stringWithFormat:@"100.0.%@", block_num];    //  REMARK：block_num 不是对象ID，特殊处理。
            [pAppCache update_object_cache:oid object:block_header];
            [_cacheObjectID2ObjectHash setObject:block_header forKey:oid];  //  add to memory cache: id hash
            [resultHash setObject:block_header forKey:oid];
        }
        //  保存缓存
        [pAppCache saveObjectCacheToFile];
        //  返回结果
        return resultHash;
    })];
}

/**
 *  (public) 查询最近成交记录
 */
- (WsPromise*)queryFillOrderHistory:(TradingPair*)tradingPair number:(NSInteger)number
{
    GrapheneApi* api_history = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_history;
    
    return [[api_history exec:@"get_fill_order_history" params:@[tradingPair.baseId, tradingPair.quoteId, @(number * 2)]]
            then:(^id(id data_array) {
        
        //  REMARK：筛选所有的 taker，吃单作为交易历史，一次交易撮合肯定有2个订单，买方和卖方，但交易历史和走向根据taker主动成交决定。
        NSMutableArray* fillOrders = [NSMutableArray array];
        for (id fillOrder in data_array) {
            id op = [fillOrder objectForKey:@"op"];
            //  REMARK：过滤掉 maker 的交易记录，仅处理 taker 的交易记录。一笔交易会产生2条记录，一个 taker，一个 maker。
            if ([[op objectForKey:@"is_maker"] boolValue]){
                continue;
            }
            id time = [fillOrder objectForKey:@"time"];
            id pays = [op objectForKey:@"pays"];
            id order_id = [op objectForKey:@"order_id"];
            //  是否是爆仓单
            BOOL isCallOrder = [[[order_id componentsSeparatedByString:@"."] objectAtIndex:1] integerValue] == ebot_call_order;
            BOOL isSell = YES;
            //  获取价格对象，注意老的API节点可能不存在该字段。
            id fill_price = [op objectForKey:@"fill_price"];
            //  price 和 amount 都按照动态计算出的精度格式化。
            double price;
            double amount;
            //  REMARK：支付的资产为 base 资产（CNY），那么即为 BUY 行为。
            if ([[pays objectForKey:@"asset_id"] isEqualToString:tradingPair.baseId]){
                isSell = NO;
                //  购买目标资产数量
                unsigned long long buy_amount = [[[op objectForKey:@"receives"] objectForKey:@"amount"] unsignedLongLongValue];
                //  REMARK：部分历史订单会出现数量为 0 的数据，直接过滤。
                if (buy_amount == 0){
                    //  TODO:fowallet 添加 flurry统计？
                    continue;
                }
                amount = buy_amount / tradingPair.quotePrecisionPow;
                
                if (fill_price){
                    id n_price = [OrgUtils calcPriceFromPriceObject:fill_price
                                                            base_id:tradingPair.quoteId
                                                     base_precision:tradingPair.quotePrecision
                                                    quote_precision:tradingPair.basePrecision
                                                             invert:NO
                                                       roundingMode:NSRoundPlain
                                               set_divide_precision:NO];
                    price = [n_price doubleValue];
                }else{
                    unsigned long long cost_amount = [[pays objectForKey:@"amount"] unsignedLongLongValue];
                    double cost_real = cost_amount / tradingPair.basePrecisionPow;
                    
                    price = cost_real / amount;
                }
            }else{
                //  卖出资产数量
                unsigned long long sell_amount = [[pays objectForKey:@"amount"] unsignedLongLongValue];
                //  REMARK：部分历史订单会出现数量为 0 的数据，直接过滤。
                if (sell_amount == 0){
                    //  TODO:fowallet 添加 flurry统计？
                    continue;
                }
                amount = sell_amount / tradingPair.quotePrecisionPow;
                
                if (fill_price){
                    id n_price = [OrgUtils calcPriceFromPriceObject:fill_price
                                                            base_id:tradingPair.quoteId
                                                     base_precision:tradingPair.quotePrecision
                                                    quote_precision:tradingPair.basePrecision
                                                             invert:NO
                                                       roundingMode:NSRoundPlain
                                               set_divide_precision:NO];
                    price = [n_price doubleValue];
                }else{
                    unsigned long long gain_amount = [[[op objectForKey:@"receives"] objectForKey:@"amount"] unsignedLongLongValue];
                    double gain_real = gain_amount / tradingPair.basePrecisionPow;
                    
                    price = gain_real / amount;
                }
            }
            
            [fillOrders addObject:@{@"time":time, @"issell":@(isSell), @"iscall":@(isCallOrder), @"price":@(price), @"amount":@(amount)}];
        }
        
        //  返回
        return fillOrders;
    })];
}

/**
 *  (public) 查询爆仓单
 */
- (WsPromise*)queryCallOrders:(TradingPair*)tradingPair number:(NSInteger)number
{
    if (!tradingPair.isCoreMarket){
        return [WsPromise resolve:@{}];
    }
    
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
    id bitasset_data_id = [[self getChainObjectByID:tradingPair.smartAssetId] objectForKey:@"bitasset_data_id"];
    assert(bitasset_data_id);
    
    id p1 = [[api exec:@"get_objects" params:@[@[bitasset_data_id]]] then:(^id(id data) {
        return [data objectAtIndex:0];
    })];
    id p2 = [api exec:@"get_call_orders" params:@[tradingPair.smartAssetId, @(number)]];
    
    return [[WsPromise all:@[p1, p2]] then:(^id(id data_array) {
        id bitasset = [data_array objectAtIndex:0];
        id callorders = [data_array objectAtIndex:1];
        
        //  准备参数
        NSInteger debt_precision;
        NSInteger collateral_precision;
        NSRoundingMode roundingMode;
        BOOL invert;
        if ([tradingPair.smartAssetId isEqualToString:tradingPair.baseId]){
            debt_precision = tradingPair.basePrecision;
            collateral_precision = tradingPair.quotePrecision;
            invert = NO;
            roundingMode = NSRoundDown;
        }else{
            debt_precision = tradingPair.quotePrecision;
            collateral_precision = tradingPair.basePrecision;
            invert = YES;   //  force sell `quote` is force buy action
            roundingMode = NSRoundUp;
        }
        
        //  计算喂价
        id current_feed = [bitasset objectForKey:@"current_feed"];
        assert(current_feed);
        id settlement_price = [current_feed objectForKey:@"settlement_price"];
        assert(settlement_price);
        NSDecimalNumber* feed_price = [OrgUtils calcPriceFromPriceObject:settlement_price
                                                                 base_id:tradingPair.sbaAssetId
                                                          base_precision:collateral_precision
                                                         quote_precision:debt_precision
                                                                  invert:NO
                                                            roundingMode:roundingMode
                                                    set_divide_precision:NO];
        
        //  REMARK：没人喂价 or 所有喂价都过期，则存在 base和quote 都为 0 的情况。即：无喂价。
        NSDecimalNumber* feed_price_market = nil;
        NSDecimalNumber* call_price_market = nil;
        NSDecimalNumber* call_price = [NSDecimalNumber zero];
        NSDecimalNumber* total_sell_amount = [NSDecimalNumber zero];
        NSDecimalNumber* n_mcr = nil;
        NSDecimalNumber* n_mssr = nil;
        NSInteger settlement_account_number = 0;
        if (feed_price){
            feed_price_market = [OrgUtils calcPriceFromPriceObject:settlement_price
                                                           base_id:tradingPair.quoteId
                                                    base_precision:tradingPair.quotePrecision
                                                   quote_precision:tradingPair.basePrecision
                                                            invert:NO
                                                      roundingMode:roundingMode
                                              set_divide_precision:YES];
            
            id mssr = [current_feed objectForKey:@"maximum_short_squeeze_ratio"];
            id mcr = [current_feed objectForKey:@"maintenance_collateral_ratio"];
            
            n_mcr = [NSDecimalNumber decimalNumberWithMantissa:[mcr unsignedLongLongValue] exponent:-3 isNegative:NO];
            n_mssr = [NSDecimalNumber decimalNumberWithMantissa:[mssr unsignedLongLongValue] exponent:-3 isNegative:NO];
            
            //  1、计算爆仓成交价   feed / mssr
            call_price_market = call_price = [feed_price decimalNumberByDividingBy:n_mssr];
            if (invert){
                call_price_market = [[NSDecimalNumber one] decimalNumberByDividingBy:call_price];
            }
            
            //  2、计算爆仓单数量
            id zero = [NSDecimalNumber zero];
            NSDecimalNumberHandler* settlement_handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                                scale:debt_precision
                                                                                                     raiseOnExactness:NO
                                                                                                      raiseOnOverflow:NO
                                                                                                     raiseOnUnderflow:NO
                                                                                                  raiseOnDivideByZero:NO];
            for (id callorder in callorders) {
                NSDecimalNumber* n_settlement_trigger_price = [OrgUtils calcSettlementTriggerPrice:callorder[@"debt"]
                                                                                        collateral:callorder[@"collateral"]
                                                                                    debt_precision:debt_precision
                                                                              collateral_precision:collateral_precision
                                                                                             n_mcr:n_mcr
                                                                                           reverse:NO
                                                                                      ceil_handler:settlement_handler
                                                                              set_divide_precision:NO];
                //  强制平仓
                if ([feed_price compare:n_settlement_trigger_price] < 0){
                    id sell_amount = [OrgUtils calcSettlementSellNumbers:callorder
                                                          debt_precision:debt_precision
                                                    collateral_precision:collateral_precision
                                                              feed_price:feed_price
                                                              call_price:call_price
                                                                     mcr:n_mcr
                                                                    mssr:n_mssr];
                    //  小数点精度可能有细微误差
                    if ([sell_amount compare:zero] <= 0){
                        continue;
                    }
                    total_sell_amount = [total_sell_amount decimalNumberByAdding:sell_amount];
                    ++settlement_account_number;
                }
            }
        }
        //  返回
        if (feed_price_market){
            assert(n_mssr && n_mcr && call_price_market);
            return @{@"feed_price_market":feed_price_market,
                     @"feed_price":feed_price,                  //  需要手动翻转价格
                     @"call_price_market":call_price_market,
                     @"call_price":call_price,                  //  需要手动翻转价格
                     @"total_sell_amount":total_sell_amount,
                     @"total_buy_amount":[total_sell_amount decimalNumberByMultiplyingBy:call_price],
                     @"invert":@(invert),
                     @"mcr":n_mcr,
                     @"mssr":n_mssr,
                     @"settlement_account_number":@(settlement_account_number)};
        }else{
            return @{};
        }
    })];
}

/**
 *  (public) 查询限价单
 */
- (WsPromise*)queryLimitOrders:(TradingPair*)tradingPair number:(NSInteger)number
{
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
//    id p1 = [api exec:@"get_call_orders" params:@[[asset objectForKey:@"id"], @50]];
//    id p2 = [[api exec:@"get_objects" params:@[@[[asset objectForKey:@"bitasset_data_id"]]]] then:(^id(id data) {
//        return [data objectAtIndex:0];
//    })];
    
    return [[api exec:@"get_limit_orders" params:@[tradingPair.baseId, tradingPair.quoteId, @(number)]] then:(^id(id data_array) {
        
        NSMutableArray* bidArray = [NSMutableArray array];
        NSMutableArray* askArray = [NSMutableArray array];
        
        id base_id = tradingPair.baseId;
        
        double bid_amount_sum = 0;
        double ask_amount_sum = 0;
        
        for (id limitOrder in data_array) {
            //{"id"=>"1.7.82635029",
            //    "expiration"=>"2019-06-18T08:17:54",
            //    "seller"=>"1.2.881146",
            //    "for_sale"=>128957118,
            //    "sell_price"=>
            //    {"base"=>{"amount"=>169535062, "asset_id"=>"1.3.0"},          #   base 是卖出的资产
            //        "quote"=>{"amount"=>15970314, "asset_id"=>"1.3.113"}},
            //    "deferred_fee"=>0},
            id sell_price = [limitOrder objectForKey:@"sell_price"];
            id base = [sell_price objectForKey:@"base"];
            id quote = [sell_price objectForKey:@"quote"];
            
            //  REMARK：卖单的base和市场的base相同，则为买单。比如，BTS-CNY市场，卖出CNY即买入BTS。
            if ([[base objectForKey:@"asset_id"] isEqualToString:base_id]){
                //  bid order: 单价price = 总价格base / 总数量quote
                double value_base = [[base objectForKey:@"amount"] unsignedLongLongValue] / tradingPair.basePrecisionPow;
                double value_quote = [[quote objectForKey:@"amount"] unsignedLongLongValue] / tradingPair.quotePrecisionPow;
                double price = value_base / value_quote;
                
                //  for_sale是卖出BASE，为总花费。比如 所有花费的CNY。
                double base_amount = [[limitOrder objectForKey:@"for_sale"] unsignedLongLongValue] / tradingPair.basePrecisionPow;
                //  总花费 / 单价，即买单的总数量。比如 BTS。
                double quote_amount = base_amount / price;  //  TODO:fowallet价格精度问题。
                
                //  累积
                bid_amount_sum += quote_amount;
                [bidArray addObject:@{@"price":@(price), @"quote":@(quote_amount), @"base":@(base_amount), @"sum":@(bid_amount_sum)}];
            }else{
                //  ask order
                
                //  REMARK：卖单的base和市场quote相同，则为实际的卖单，比如，BTS-CNY市场，卖出BTS。
                double sell_value = [[base objectForKey:@"amount"] unsignedLongLongValue] / tradingPair.quotePrecisionPow;
                double buy_value = [[quote objectForKey:@"amount"] unsignedLongLongValue] / tradingPair.basePrecisionPow;
                double price = buy_value / sell_value;
                
                //  for_sale是卖出QUOTE，即卖出BTS的数量。
                double quote_amount = [[limitOrder objectForKey:@"for_sale"] unsignedLongLongValue] / tradingPair.quotePrecisionPow;
                
                //  总花费 = 单价 * 数量。
                double base_amount = quote_amount * price;
                
                //  累积
                ask_amount_sum += quote_amount;
                [askArray addObject:@{@"price":@(price), @"quote":@(quote_amount), @"base":@(base_amount), @"sum":@(ask_amount_sum)}];
            }
        }
        
        return @{@"bids":bidArray, @"asks":askArray};
    })];
}

/**
 *  (public) 查询指定帐号的完整信息
 */
- (WsPromise*)queryFullAccountInfo:(NSString*)account_name_or_id
{
    assert(account_name_or_id);
    //  TODO:fowallet 部分api结点，帐号不存在不是返回nil而是抛出异常。
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    return [[api exec:@"get_full_accounts" params:@[@[account_name_or_id], @FALSE]] then:(^id(id data) {
        //  帐号不存在
        if (!data || [data isKindOfClass:[NSNull class]] || [data count] <= 0){
            return nil;
        }
        //  获取帐号信息
        id full_account_data = [[data objectAtIndex:0] objectAtIndex:1];
        //  [缓存] 添加到缓存
        id account = [full_account_data objectForKey:@"account"];
        [_cacheUserFullAccountData setObject:full_account_data forKey:account[@"id"]];
        [_cacheUserFullAccountData setObject:full_account_data forKey:account[@"name"]];
        return full_account_data;
    })];
}

/**
 * (public) 账号是否存在于区块链上
 */
- (WsPromise*)isAccountExistOnBlockChain:(NSString*)account_name
{
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    return [[api exec:@"get_account_by_name" params:@[account_name]] then:(^id(id data) {
        if (!data || [data isKindOfClass:[NSNull class]] || [[data objectForKey:@"id"] isEqualToString:@""]){
            return @NO;
        }else{
            return @YES;
        }
    })];
}

/**
 *  (public) 通过公钥查询所有关联的账号信息。
 */
- (WsPromise*)queryAccountDataHashFromKeys:(NSArray*)pubkeyList
{
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    return [[api exec:@"get_key_references" params:@[pubkeyList]] then:(^id(id key_data_array) {
        NSMutableDictionary* account_id_hash = [NSMutableDictionary dictionary];
        for (id account_array in key_data_array) {
            for (id account_id in account_array) {
                [account_id_hash setObject:@YES forKey:account_id];
            }
        }
        if ([account_id_hash count] <= 0){
            return @{};
        }else{
            return [self queryAllAccountsInfo:[account_id_hash allKeys]];
        }
    })];
}

/**
 *  (public) 查询指定用户的限价单（当前委托信息）
 */
- (WsPromise*)queryUserLimitOrders:(NSString*)account_name_or_id
{
    return [[self queryFullAccountInfo:account_name_or_id] then:(^id(id full_account_data) {
        if (!full_account_data){
            return nil;
        }
        //  查询当前委托订单中所有关联的 asset 信息。
        NSMutableDictionary* asset_id_hash = [NSMutableDictionary dictionary];
        id limit_orders = [full_account_data objectForKey:@"limit_orders"];
        if (limit_orders && [limit_orders count] > 0){
            for (id order in limit_orders) {
                id sell_price = [order objectForKey:@"sell_price"];
                [asset_id_hash setObject:@YES forKey:[[sell_price objectForKey:@"base"] objectForKey:@"asset_id"]];
                [asset_id_hash setObject:@YES forKey:[[sell_price objectForKey:@"quote"] objectForKey:@"asset_id"]];
            }
        }
        return [[self queryAllAssetsInfo:[asset_id_hash allKeys]] then:(^id(id data) {
            return full_account_data;
        })];
    })];
}

/**
 *  (public) 查询最新的预算项目，可能返回 nil值。
 */
- (WsPromise*)queryLastBudgetObject
{
    //  根据当前时间戳计算和基准参考时间的差值，然后计算预期的预算项目ID。
    id parameters = [self getDefaultParameters];
    assert(parameters);
    id base_budget_id = parameters[@"base_budget_id"];
    id base_budget_time = parameters[@"base_budget_time"];
    assert(base_budget_id);
    assert(base_budget_time);
    
    //  获取基准ID
    id oid = [[base_budget_id componentsSeparatedByString:@"."] lastObject];
    unsigned long long ll_oid = [oid unsignedLongLongValue];
    
    NSTimeInterval ts_base = [OrgUtils parseBitsharesTimeString:base_budget_time];
    NSTimeInterval ts_curr = [[NSDate date] timeIntervalSince1970];
    
    NSInteger elapse_hours = fmaxf(floorf((ts_curr - ts_base) / 3600.0), 0);
    
    //  REMARK：由于整点维护、或者区块链系统宕机等缘故，预算项目并未精确一致，可能存在少许几个的误差。所以这里一次性查询多个预算项目。
    NSInteger latest_oid = ll_oid + elapse_hours;
    NSMutableArray* query_oid_list = [NSMutableArray array];
    for (NSInteger i = 0; i <= 10; ++i) {
        [query_oid_list addObject:[NSString stringWithFormat:@"2.13.%@", @(latest_oid - i)]];
    }
    return [[self queryAllObjectsInfo:query_oid_list cacheContainer:nil cacheObjectKey:nil skipQueryCache:NO skipCacheIdHash:nil] then:(^id(id asset_hash) {
        id budget_object = nil;
        for (id check_oid in query_oid_list) {
            budget_object = [asset_hash objectForKey:check_oid];
            if (budget_object){
                break;
            }
        }
        if (!budget_object){
            //  TODO:fowallet 添加统计
            NSLog(@"no budget object: %@", @(latest_oid));
        }
        return budget_object;
    })];
}

/**
 *  (public) 查询帐号投票信息（如果帐号设置了代理帐号，则继续查询代理帐号的投票信息。代理层级过多则返回空。）
 *  account_data    - full_account_data 的 account 部分。
 *  返回值：
 *      {voting_hash,       - 投票ID等Hash
 *       voting_account,    - 实际执行投票的帐号信息
 *       proxy_level,       - 代理层级（没代理则为0。）
 *       have_proxy         - 是否设置了代理人
 *      }
 */
- (WsPromise*)queryAccountVotingInfos:(id)account_name_or_id
{
    return [[self queryFullAccountInfo:account_name_or_id] then:(^id(id full_account_data) {
        assert(full_account_data);
        return [self _queryAccountVotingInfosCore:[full_account_data objectForKey:@"account"]
                                           result:[NSMutableDictionary dictionary]
                                            level:0
                                          checked:[NSMutableDictionary dictionary]];
        
    })];
}
- (WsPromise*)_queryAccountVotingInfosCore:(id)account_data
                                    result:(NSMutableDictionary*)resultHash
                                     level:(NSInteger)level
                                   checked:(NSMutableDictionary*)checked_hash;
{
    assert(account_data);
    assert(resultHash);
    assert(checked_hash);
    id options = [account_data objectForKey:@"options"];
    assert(options);
    
    //  设置标记，防止两个帐号循环设置代理导致死循环。
    [checked_hash setObject:@YES forKey:[account_data objectForKey:@"id"]];
    
    id voting_account_id = [options objectForKey:@"voting_account"] ;
    
    //  未设置代理帐号，则返回。
    id parameters = [self getDefaultParameters];
    assert(parameters);
    id voting_proxy_to_self = [parameters objectForKey:@"voting_proxy_to_self"];
    assert(voting_proxy_to_self);
    
    BOOL proxy_to_self = [voting_account_id isEqualToString:voting_proxy_to_self];
    if (proxy_to_self){
        for (id vote_id in [options objectForKey:@"votes"]) {
            [resultHash setObject:@YES forKey:vote_id];
        }
        return [WsPromise resolve:@{@"voting_hash":[resultHash copy],
                                    @"voting_account":account_data,
                                    @"proxy_level":@(level),
                                    @"have_proxy":@(level!=0)}];
    }
    
    //  最大递归层数
    if (level >= [[parameters objectForKey:@"voting_proxy_max_level"] integerValue]){
        return [WsPromise resolve:@{@"voting_hash":[resultHash copy],
                                    @"voting_account":account_data,
                                    @"proxy_level":@(level),
                                    @"have_proxy":@(level!=0)}];
    }
    
    //  代理帐号以前查询过了，循环代理。直接返回。
    if ([[checked_hash objectForKey:voting_account_id] boolValue]){
        return [WsPromise resolve:@{@"voting_hash":[resultHash copy],
                                    @"voting_account":account_data,
                                    @"proxy_level":@(level),
                                    @"have_proxy":@(level!=0)}];
    }
    
    //  当前帐号设置了代理，继续递归查询。
    //  TODO:fowallet 统计数据
    NSLog(@"[Voting Proxy] Query proxy account: %@, level: %@", voting_account_id, @(level + 1));
    return [[self queryAllObjectsInfo:@[voting_account_id] cacheContainer:nil cacheObjectKey:nil skipQueryCache:YES skipCacheIdHash:nil] then:(^id(id data_hash) {
        id proxy_account_data = [data_hash objectForKey:voting_account_id];
        assert(proxy_account_data);
        return [self _queryAccountVotingInfosCore:proxy_account_data result:resultHash level:level + 1 checked:checked_hash];
    })];
}


@end
