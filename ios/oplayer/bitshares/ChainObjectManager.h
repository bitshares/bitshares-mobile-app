//
//  ChainObjectManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>
#import "AppCacheManager.h"
#import "WsPromise.h"

#include "bts_wallet_core.h"

@class TradingPair;

@interface ChainObjectManager : NSObject

/**
 *  各种属性定义
 */
@property (nonatomic, assign) BOOL isTestNetwork;               //  是否是测试网络
@property (nonatomic, copy) NSString* grapheneChainID;          //  石墨烯区块链ID
@property (nonatomic, copy) NSString* grapheneCoreAssetID;      //  石墨烯网络核心资产ID
@property (nonatomic, copy) NSString* grapheneCoreAssetSymbol;  //  石墨烯网络核心资产名称
@property (nonatomic, copy) NSString* grapheneAddressPrefix;    //  石墨烯网络地址前缀

+ (ChainObjectManager*)sharedChainObjectManager;

/**
 *  (public) 启动初始化
 */
- (void)initConfig;

/**
 *  (public) 生成所有市场的分组信息（包括内置交易对和自定义交易对）初始化调用、每次添加删除自定义交易对时调用。
 */
- (void)buildAllMarketsInfos;

/**
 *  (public) 是否是内置交易对判断
 */
- (BOOL)isDefaultPair:(id)quote base:(id)base;
- (BOOL)isDefaultPair:(NSString*)base_symbol quote:(id)quote;
- (BOOL)isDefaultPair:(NSString*)base_symbol quote_symbol:(NSString*)quote_symbol;

/**
 *  (public) 获取部分默认配置参数
 */
- (NSDictionary*)getDefaultParameters;

/**
 *  (public) 获取APP中各种URL配置
 */
- (NSString*)getAppEmbeddedUrl:(NSString*)url_key lang_key:(NSString*)lang_key;

/*
 *  (public) 获取APP配置文件中出现的所有资产符号。初始化时需要查询所有依赖的资产信息。
 */
- (NSArray*)getConfigDependenceAssetSymbols;

/**
 *  (public) 获取水龙头部分配置参数
 */
- (NSDictionary*)getDefaultFaucet;

/**
 * (public) 获取最后选用的水龙头注册地址
 */
- (NSString*)getFinalFaucetURL;

/**
 *  (public) 主要智能币快捷选择列表。
 */
- (NSArray*)getMainSmartAssetList;

/**
 *  (public) 获取手续费列表（按照列表优先选择）
 */
- (NSArray*)getFeeAssetSymbolList;

/**
 *  (public) 获取支持的记账单位列表
 */
- (NSArray*)getEstimateUnitList;

/**
 *  (public) 获取默认的记账单位，列表的第一个。
 */
- (NSString*)getDefaultEstimateUnitSymbol;

/**
 *  (public) 根据计价货币symbol获取计价单位配置信息
 */
- (NSDictionary*)getEstimateUnitBySymbol:(NSString*)symbol;

/**
 *  (public) 获取网络配置信息
 */
- (NSDictionary*)getCfgNetWorkInfos;

/**
 *  (public) 获取资产作为交易对中的 base 资产的优先级，两者之中，优先级高的作为 base，另外一个作为 quote。
 */
- (NSDictionary*)genAssetBasePriorityHash;

/**
 *  (public) 获取最终的市场列表信息（默认 + 自定义）
 */
- (NSArray*)getMergedMarketInfos;

/**
 *  (public) 获取默认的 markets 列表信息
 */
- (NSArray*)getDefaultMarketInfos;

/**
 *  (public) 根据 base_symbol 获取 market 信息。
 */
- (NSDictionary*)getDefaultMarketInfoByBaseSymbol:(NSString*)base_symbol;

/**
 *  (public) 获取默认所有的分组信息
 */
- (NSDictionary*)getDefaultGroupInfos;

/**
 *  (public) 获取 or 更新全局属性信息（包括活跃理事会、活跃见证人、手续费等信息）REMARK：该对象ID固定为 2.0.0。
 */
- (NSDictionary*)getObjectGlobalProperties;
- (void)updateObjectGlobalProperties:(NSDictionary*)gp;
- (WsPromise*)queryGlobalProperties;

/**
 *  (public) 获取指定分组信息
 */
- (NSDictionary*)getGroupInfoFromGroupKey:(NSString*)group_key;

/**
 *  根据名字、符号、ID等获取各种区块链对象。
 */
- (id)getAssetBySymbol:(NSString*)symbol;
- (id)getChainObjectByID:(NSString*)oid;
- (id)getChainObjectByID:(NSString*)oid searchFileCache:(BOOL)searchFileCache;

/*
 *  (public) 从文件缓冲中根据资产符号名查询资产ID信息。
 */
- (NSDictionary*)getAssetIdFromFileCache:(NSArray*)asset_symbols;

- (id)getVoteInfoByVoteID:(NSString*)vote_id;
- (id)getAccountByName:(NSString*)name;
- (id)getBlockHeaderInfoByBlockNumber:(id)block_number;
- (id)getFullAccountDataFromCache:(id)account_id_or_name;

/**
 *  添加资产
 */
- (void)appendAssets:(NSDictionary*)assets_name2obj_hash;

/*
 *  (public) 添加到内存 cache
 */
- (void)appendAssetCore:(id)asset;

/**
 *  (public) 更新缓存
 */
- (void)updateGrapheneObjectCache:(NSArray*)data_array;

#pragma mark- aux method
/*
 *  (public) 计算以核心资产为单位的网络手续费数量。
 */
- (NSDecimalNumber*)getNetworkCurrentFee:(EBitsharesOperations)op_code
                                   kbyte:(NSDecimalNumber*)n_kbyte
                                     day:(NSDecimalNumber*)n_day
                                  output:(NSDecimalNumber*)n_output;

/**
 *  (public) 获取手续费对象
 */
- (NSDictionary*)getFeeItem:(EBitsharesOperations)op_code full_account_data:(NSDictionary*)full_account_data;
- (NSDictionary*)getFeeItem:(EBitsharesOperations)op_code full_account_data:(NSDictionary*)full_account_data extra_balance:(NSDictionary*)extra_balance;

/**
 *  (public) 评估指定交易操作所需要的手续费信息
 */
- (NSDictionary*)estimateFeeObject:(EBitsharesOperations)op
                 full_account_data:(NSDictionary*)full_account_data
                     extra_balance:(NSDictionary*)extra_balance;

- (NSDictionary*)estimateFeeObject:(EBitsharesOperations)op
                          balances:(NSArray*)balance_list;

#pragma mark- init graphene network
/**
 *  (public) 石墨烯网络初始化，优先调用。
 */
- (WsPromise*)grapheneNetworkInit;

#pragma mark- for ticker data
/**
 *  启动 app 时初始化所有市场的 ticker 数据。（包括自定义市场）
 */
- (WsPromise*)marketsInitAllTickerData;
/**
 *  查询Ticker数据（参数：base、quote构成的Hash的列表。）
 */
- (WsPromise*)queryTickerDataByBaseQuoteSymbolArray:(NSArray*)base_quote_symbol_array;
/**
 *  获取行情的 ticker 数据
 */
- (NSDictionary*)getTickerData:(NSString*)base_symbol quote:(NSString*)quote_symbol;
/**
 *  更新 ticker 数据
 */
- (void)updateTickeraData:(NSString*)base_symbol quote:(NSString*)quote_symbol data:(NSDictionary*)ticker;
- (void)updateTickeraData:(NSString*)pair data:(NSDictionary*)ticker;

#pragma mark- query blocchain data
/**
 *  (public) 查询手续费资产的详细信息（包括动态信息）
 */
- (WsPromise*)queryFeeAssetListDynamicInfo;

/**
 *  (public) 根据资产名查询资产信息。
 */
- (WsPromise*)queryAssetsBySymbols:(NSArray*)symbols ids:(NSArray*)asset_ids;

/**
 *  (public) 查询所有投票ID信息
 */
- (WsPromise*)queryAllVoteIds:(NSArray*)vote_id_array;
- (WsPromise*)queryAllAccountsInfo:(NSArray*)account_id_array;
- (WsPromise*)queryAllAssetsInfo:(NSArray*)asset_id_array;
/**
 *  (public) 查询对象信息（优先查询缓存）
 */
- (WsPromise*)queryAllGrapheneObjects:(NSArray*)id_array;
/**
 *  (public) 查询对象信息（全部跳过缓存）
 */
- (WsPromise*)queryAllGrapheneObjectsSkipCache:(NSArray*)id_array;
/**
 *  (public) 查询对象信息（部分跳过缓存）
 */
- (WsPromise*)queryAllGrapheneObjects:(NSArray*)id_array skipCacheIdHash:(NSDictionary*)skipCacheIdHash;

/**
 *  (public) 查询所有 block_num 的 header 信息，返回 Hash。 格式：{对象ID=>对象信息, ...}
 *
 *  skipQueryCache - 控制是否查询缓存
 *
 *  REMARK：不处理异常，在外层 VC 逻辑中处理。外部需要 catch 该 promise。
 */
- (WsPromise*)queryAllBlockHeaderInfos:(NSArray*)block_num_array skipQueryCache:(BOOL)skipQueryCache;

/*
 *  (public) 查询链上区块数据。
 */
- (WsPromise*)queryBlock:(NSUInteger)block_num;

/*
 *  (public) 查询指定账号指定类型的账号明细列表。
 */
- (WsPromise*)queryAccountHistoryByOperations:(NSString*)account_id_or_name optype_array:(NSArray*)optype_array limit:(NSInteger)limit;

/*
 *  (public) 根据资产创建者查询资产信息。
 */
- (WsPromise*)queryAssetsByIssuer:(NSString*)issuer_name_or_id start:(NSString*)start limit:(NSInteger)limit;

/**
 *  (public) 查询最近成交记录
 */
- (WsPromise*)queryFillOrderHistory:(TradingPair*)tradingPair number:(NSInteger)number;

/*
 *  (public) 根据资产 - 查询强清单
 */
- (WsPromise*)querySettlementOrders:(NSString*)smart_asset_symbol_or_id number:(NSInteger)number;

/*
 *  (public) 根据用户 - 查询强清单
 */
- (WsPromise*)querySettlementOrdersByAccount:(NSString*)account_name_or_id number:(NSInteger)number;

/**
 *  (public) 查询爆仓单
 */
- (WsPromise*)queryCallOrders:(TradingPair*)tradingPair number:(NSInteger)number;

/**
 *  (public) 查询限价单
 */
- (WsPromise*)queryLimitOrders:(TradingPair*)tradingPair number:(NSInteger)number;

/**
 *  (public) 查询指定帐号的完整信息
 */
- (WsPromise*)queryFullAccountInfo:(NSString*)account_name_or_id;

/**
 *  (public) 查询完整账号信息，带重试。REMARK：刚注册成功的账号可能查询失败，网络尚未同步完毕。
 */
- (WsPromise*)queryFullAccountInfo:(NSString*)account_name_or_id retry_num:(NSInteger)retry_num;

/**
 * (public) 查询账号基本信息
 */
- (WsPromise*)queryAccountData:(NSString*)account_name_or_id;

/**
 * (public) 查询资产基本信息
 */
- (WsPromise*)queryAssetData:(NSString*)asset_symbol_or_id;
- (WsPromise*)queryAssetDataList:(NSArray*)asset_name_list;

/*
 *  (public) 查询指定账号余额
 */
- (WsPromise*)queryAccountBalance:(NSString*)account_name_or_id assets:(NSArray*)asset_id_array;

/**
 * (public) 账号是否存在于区块链上
 */
- (WsPromise*)isAccountExistOnBlockChain:(NSString*)account_name;

/**
 *  (public) 通过公钥查询所有关联的账号信息。
 */
- (WsPromise*)queryAccountDataHashFromKeys:(NSArray*)pubkeyList;

/**
 *  (public) 查询指定用户的限价单（当前委托信息）
 */
- (WsPromise*)queryUserLimitOrders:(NSString*)account_name_or_id;

/*
 *  (public) 查询指定【智能资产】的【背书资产】数据。
 */
- (WsPromise*)queryBackingAsset:(id)smart_asset;

/*
 *  (public) 查询指定背书资产的次级背书资产信息。
 */
- (WsPromise*)queryBackingBackingAsset:(id)backing_asset;

/**
 *  (public) 查询最新的预算项目
 */
- (WsPromise*)queryLastBudgetObject;

/*
    (public) 获取活跃的见证人信息列表。
 */
- (WsPromise*)queryActiveWitnessDataList;

/*
   (public) 获取活跃的理事会成员信息列表。
*/
- (WsPromise*)queryActiveCommitteeDataList;

/**
 *  (public) 查询帐号投票信息（如果帐号设置了代理帐号，则继续查询代理帐号的投票信息。代理层级过多则返回空。）
 */
- (WsPromise*)queryAccountVotingInfos:(id)account_name_or_id;

/*
 * (public) 查询账号链上自定义存储的数据。
 */
- (WsPromise*)queryAccountStorageInfo:(NSString*)account_name_or_id catalog:(NSString*)catalog;

@end
