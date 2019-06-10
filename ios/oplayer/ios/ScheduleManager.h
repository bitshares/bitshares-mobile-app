//
//  ScheduleManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//  定时任务调度管理器

#import <Foundation/Foundation.h>
#import "TradingPair.h"
#import "GrapheneWebSocket.h"

//  Ticker更新时间间隔 最大值和最小值 单位：毫秒
#define kScheduleTickerIntervalMin  500.0f
#define kScheduleTickerIntervalMax  300000.0f

//  Ticker更新失败时，时间间隔调整系数，可增大也可降低。
#define kScheduleTickerIntervalErrorFactor  0.9f

//  Ticker更新数据没变化时，每次递增间隔。
#define kScheduleTickerIntervalStep  1000.0f

/**
 *  Ticker 任务数据定义
 */
@interface ScheduleTickerUpdate : NSObject

@property (nonatomic, copy) NSString*           quote;
@property (nonatomic, copy) NSString*           base;
@property (nonatomic, strong) NSString*         pair;

@property (nonatomic, assign) BOOL              querying;           //  是否正在执行请求中

@property (nonatomic, strong) NSString*         last_quote_volume;

@property (nonatomic, assign) NSTimeInterval    interval_milliseconds;
@property (nonatomic, assign) NSTimeInterval    accumulated_milliseconds;

@end

//  [通知]
#define kBtsSubMarketNotifyNewData  @"kBtsSubMarketNotifyNewData"

//  订阅交易对信息最小更新间隔（即在这个间隔内不管是否有notify都不会更新。）REMARK：目前这个值实际最低在3s左右，因为3s是一个区块的生成最短间隔。
#define kScheduleSubMarketIntervalMin  500.0f

//  订阅交易对信息最大更新间隔（即超过这间隔不管是否有notify都会更新。）
#define kScheduleSubMarketIntervalMax  120000.0f

/**
 *  SubMarket 订阅交易对消息数据定义
 */
@interface ScheduleSubMarket : NSObject
@property (nonatomic, assign) NSInteger             refCount;           //  K线界面、交易界面都会订阅（需要添加计数）

@property (nonatomic, strong) WsNotifyCallback      callback;
@property (nonatomic, strong) TradingPair*          tradingPair;
@property (nonatomic, assign) BOOL                  subscribed;         //  是否订阅中

@property (nonatomic, assign) BOOL                  querying;           //  是否正在执行请求中

@property (nonatomic, strong) NSMutableDictionary*  monitorOrderStatus; //  监控指定订单状态

@property (nonatomic, assign) BOOL                  updateMonitorOrder; //  是否有监控中订单更新（新增、更新、删除）
@property (nonatomic, assign) BOOL                  updateLimitOrder;   //  是否有限价单更新（新增、更新、删除）
@property (nonatomic, assign) BOOL                  updateCallOrder;    //  是否有抵押单更新（新增、更新、删除）
@property (nonatomic, assign) BOOL                  hasFillOrder;       //  是否有新的成交记录

@property (nonatomic, assign) NSTimeInterval        accumulated_milliseconds;

//  部分配置参数
@property (nonatomic, assign) NSInteger             cfgCallOrderNum;    //  [配置] 每次更新时获取爆仓单数量
@property (nonatomic, assign) NSInteger             cfgLimitOrderNum;   //  [配置] 每次更新时获取限价单数量
@property (nonatomic, assign) NSInteger             cfgFillOrderNum;    //  [配置] 每次更新时获取成交记录数量
@end

@interface ScheduleManager : NSObject

+ (ScheduleManager*)sharedScheduleManager;

/**
 *  根据合并后的市场信息自动添加 or 移除 ticker 更新计划。
 */
- (void)autoRefreshTickerScheduleByMergedMarketInfos;
- (void)addTickerUpdateSchedule:(NSString*)base_symbol quote:(NSString*)quote_symbol;
- (void)removeTickerUpdateSchedule:(NSString*)base_symbol quote:(NSString*)quote_symbol;
- (void)removeAllTickerSchedule;

#pragma mark- for sub markets
/**
 *  监控订单更新
 */
- (void)sub_market_monitor_orders:(TradingPair*)tradingPair order_ids:(NSArray*)order_ids account_id:(NSString*)account_id;
- (void)sub_market_remove_monitor_order:(TradingPair*)tradingPair order_id:(NSString*)order_id;
- (void)sub_market_remove_all_monitor_orders:(TradingPair*)tradingPair;
- (void)sub_market_monitor_order_update:(TradingPair*)tradingPair updated:(BOOL)updated;

/**
 *  订阅市场的通知信息
 */
- (BOOL)sub_market_notify:(TradingPair*)tradingPair
              n_callorder:(NSInteger)n_callorder
             n_limitorder:(NSInteger)n_limitorder
              n_fillorder:(NSInteger)n_fillorder;
- (void)unsub_market_notify:(TradingPair*)tradingPair;

@end
