//
//  ScheduleManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "ScheduleManager.h"
#import "GrapheneConnectionManager.h"
#import "ChainObjectManager.h"
#import "TempManager.h"
#import "AppCommon.h"
#import "OrgUtils.h"

#import <Crashlytics/Crashlytics.h>

@implementation ScheduleTickerUpdate
@synthesize quote, base, pair;
@synthesize querying;
@synthesize last_quote_volume;
@synthesize interval_milliseconds, accumulated_milliseconds;
@end

@implementation ScheduleSubMarket
@synthesize refCount;
@synthesize callback, tradingPair, subscribed;
@synthesize querying;
@synthesize monitorOrderStatus, updateMonitorOrder;
@synthesize updateLimitOrder, updateCallOrder, hasFillOrder;
@synthesize accumulated_milliseconds;
@synthesize cfgCallOrderNum, cfgLimitOrderNum, cfgFillOrderNum;
@end

static ScheduleManager *_sharedScheduleManager = nil;

@interface ScheduleManager()
{
    NSTimer*                _timer_per_seconds;     //  秒精度定时器
    NSTimeInterval          _ts_last_tick;
    
    NSMutableDictionary*    _task_hash_ticker;
    
    NSMutableDictionary*    _sub_market_infos;      //  订阅市场
}
@end

@implementation ScheduleManager

+(ScheduleManager *)sharedScheduleManager
{
    @synchronized(self)
    {
        if(!_sharedScheduleManager)
        {
            _sharedScheduleManager = [[ScheduleManager alloc] init];
        }
        return _sharedScheduleManager;
    }
}

/**
 *  [事件] 网络重连成功
 */
- (void)onWebsocketReconnectSuccess:(NSNotification*)notification
{
    for (NSString* pair in _sub_market_infos) {
        ScheduleSubMarket* s = _sub_market_infos[pair];
        //  重新订阅
        [self _sub_market_notify_core:s];
        //  [统计]
        [OrgUtils logEvents:@"event_resubscribe_to_market"
                       params:@{@"base":s.tradingPair.baseAsset[@"symbol"], @"quote":s.tradingPair.quoteAsset[@"symbol"]}];
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _task_hash_ticker = [NSMutableDictionary dictionary];
        _sub_market_infos = [NSMutableDictionary dictionary];
        _ts_last_tick = CFAbsoluteTimeGetCurrent();
        _timer_per_seconds = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(onTimerTick:) userInfo:nil repeats:YES];
        [_timer_per_seconds fire];
        //  添加事件监控：网络重连成功
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onWebsocketReconnectSuccess:)
                                                     name:kBtsWebsocketReconnectSuccess
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    //  移除监控
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kBtsWebsocketReconnectSuccess object:nil];
    if (_timer_per_seconds){
        [_timer_per_seconds invalidate];
        _timer_per_seconds = nil;
    }
}

/**
 *  根据合并后的市场信息自动添加 or 移除 ticker 更新计划。
 */
- (void)autoRefreshTickerScheduleByMergedMarketInfos
{
//    //  TODO:DEBUG only test BTS
//    [self addTickerUpdateSchedule:@"CNY" quote:@"BTS"];
//    return;
    
    //  标记Hash
    NSMutableDictionary* marker = [NSMutableDictionary dictionary];
    
    //  遍历新市场信息
    for (NSDictionary* market in [[ChainObjectManager sharedChainObjectManager] getMergedMarketInfos]) {
        id base_symbol = [[market objectForKey:@"base"] objectForKey:@"symbol"];
        id group_list = [market objectForKey:@"group_list"];
        for (NSDictionary* group_info in group_list) {
            id quote_list = [group_info objectForKey:@"quote_list"];
            for (NSString* quote_symbol in quote_list) {
                //  REMARK：pair格式：#{base_symbol}_#{quote_symbol}
                id pair = [NSString stringWithFormat:@"%@_%@", base_symbol, quote_symbol];
                //  当前schedule没包含该交易对，则添加。
                id task = _task_hash_ticker[pair];
                if (!task){
                    [self addTickerUpdateSchedule:base_symbol quote:quote_symbol];
                }
                marker[pair] = @YES;
            }
        }
    }
    
    //  编译所有ticker的schedule，如果有多余的则删除。
    for (NSString* pair in [_task_hash_ticker allKeys]) {
        if (![marker[pair] boolValue]){
            [_task_hash_ticker removeObjectForKey:pair];
        }
    }
}

- (void)addTickerUpdateSchedule:(NSString*)base_symbol quote:(NSString*)quote_symbol
{
    assert(base_symbol);
    assert(quote_symbol);
    
    ScheduleTickerUpdate* s = [[ScheduleTickerUpdate alloc] init];
    s.quote = quote_symbol;
    s.base = base_symbol;
    //  REMARK：pair格式：#{base_symbol}_#{quote_symbol}
    s.pair = [NSString stringWithFormat:@"%@_%@", base_symbol, quote_symbol];
    s.querying = NO;
    s.last_quote_volume = nil;
    //  新添加时间隔为0，立即触发。
    s.interval_milliseconds = 0;
    s.accumulated_milliseconds = 0;
    
    //  添加到计划Hash
    _task_hash_ticker[s.pair] = s;
}

- (void)removeTickerUpdateSchedule:(NSString*)base_symbol quote:(NSString*)quote_symbol
{
    assert(base_symbol);
    assert(quote_symbol);
    //  REMARK：pair格式：#{base_symbol}_#{quote_symbol}
    id pair = [NSString stringWithFormat:@"%@_%@", base_symbol, quote_symbol];
    [_task_hash_ticker removeObjectForKey:pair];
}

- (void)removeAllTickerSchedule
{
    if (_task_hash_ticker){
        [_task_hash_ticker removeAllObjects];
    }
}

#pragma mark- time ticker
- (void)_processTickerTimeTick:(NSTimer*)timer dt:(NSTimeInterval)dt
{
    //  没有任何计划任务
    if ([_task_hash_ticker count] <= 0){
        return;
    }
    
    //  当前网络未连接则不处理。
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    GrapheneConnection* conn = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection];
    BOOL closed = [conn isClosed];
    GrapheneApi* api = conn.api_db;
    
    for (NSString* key in _task_hash_ticker) {
        ScheduleTickerUpdate* task = _task_hash_ticker[key];
        //  已经在更新中（不处理 tick）
        if (task.querying){
            continue;
        }
        task.accumulated_milliseconds += dt;
        //  网络连接断开，仅累积时间，不执行更新请求。等待网络恢复后请求。
        if (closed){
            continue;
        }
        if (task.accumulated_milliseconds < task.interval_milliseconds){
            continue;
        }
        NSLog(@"schedule task update ticker: %@ interval: %0.6f", task.pair, task.interval_milliseconds);
        //  设置标记
        task.querying = YES;
        [[[api exec:@"get_ticker" params:@[task.base, task.quote]] then:(^id(id ticker_data) {
            //  清除标记
            task.querying = NO;
            [chainMgr updateTickeraData:task.pair data:ticker_data];
            id curr_quote_volume = [NSString stringWithFormat:@"%@", [ticker_data objectForKey:@"quote_volume"]];
            id last_quote_volume = task.last_quote_volume;
            if (!last_quote_volume || ![last_quote_volume isEqualToString:curr_quote_volume]){
                //  ticker有更新（间隔调整到最低）
                NSLog(@"schedule task %@ curr_quote_volume %@, YES.", task.pair, curr_quote_volume);
                task.interval_milliseconds = kScheduleTickerIntervalMin;
                task.accumulated_milliseconds = 0;
                //  设置脏标记
                [TempManager sharedTempManager].tickerDataDirty = YES;
            }else{
                //  ticker没更新（间隔增加）
                NSLog(@"schedule task %@ curr_quote_volume %@, NO.", task.pair, curr_quote_volume);
                task.interval_milliseconds = fmin(task.interval_milliseconds + kScheduleTickerIntervalStep, kScheduleTickerIntervalMax);
                task.accumulated_milliseconds = 0;
            }
            //  记录当前数据
            task.last_quote_volume = curr_quote_volume;
            return nil;
        })] catch:(^id(id error) {
            //  清除标记
            task.querying = NO;
            //  ticker请求异常，本次更新失败（间隔降低一定比例。）
            task.interval_milliseconds *= kScheduleTickerIntervalErrorFactor;
            task.accumulated_milliseconds = 0;
            return nil;
        })];
    }
}

- (void)onTimerTick:(NSTimer*)timer
{
    //  REMARK：NSTimer触发时间不太准确，这里自己计算时间间隔。
    NSTimeInterval now_ts = CFAbsoluteTimeGetCurrent();
    NSTimeInterval dt = (now_ts - _ts_last_tick) * 1000;
    _ts_last_tick = now_ts;
    
    //  更新 ticker 任务
    [self _processTickerTimeTick:timer dt:dt];
    
    //  更新订阅任务
    [self _processSubMarketTimeTick:timer dt:dt];
}

#pragma mark- for sub market
/**
 *  监控订单更新
 */
- (void)sub_market_monitor_orders:(TradingPair*)tradingPair order_ids:(NSArray*)order_ids account_id:(NSString*)account_id
{
    assert(tradingPair);
    assert(order_ids);
    assert(account_id);
    ScheduleSubMarket* s = [_sub_market_infos objectForKey:tradingPair.pair];
    if (!s){
        return;
    }
    assert(s.monitorOrderStatus);
    for (id order_id in order_ids) {
        [s.monitorOrderStatus setObject:account_id forKey:order_id];
    }
}
- (void)sub_market_remove_monitor_order:(TradingPair*)tradingPair order_id:(NSString*)order_id
{
    assert(tradingPair);
    assert(order_id);
    ScheduleSubMarket* s = [_sub_market_infos objectForKey:tradingPair.pair];
    if (!s){
        return;
    }
    assert(s.monitorOrderStatus);
    [s.monitorOrderStatus removeObjectForKey:order_id];
}
- (void)sub_market_remove_all_monitor_orders:(TradingPair*)tradingPair
{
    assert(tradingPair);
    ScheduleSubMarket* s = [_sub_market_infos objectForKey:tradingPair.pair];
    if (!s){
        return;
    }
    assert(s.monitorOrderStatus);
    [s.monitorOrderStatus removeAllObjects];
}
- (void)sub_market_monitor_order_update:(TradingPair*)tradingPair updated:(BOOL)updated
{
    assert(tradingPair);
    ScheduleSubMarket* s = [_sub_market_infos objectForKey:tradingPair.pair];
    if (!s){
        return;
    }
    s.updateMonitorOrder = updated;
}

/**
 *  订阅市场的通知信息
 */
- (BOOL)sub_market_notify:(TradingPair*)tradingPair
              n_callorder:(NSInteger)n_callorder
             n_limitorder:(NSInteger)n_limitorder
              n_fillorder:(NSInteger)n_fillorder
{
    assert(tradingPair);
    //  已经订阅（不重复添加）
    ScheduleSubMarket* s = [_sub_market_infos objectForKey:tradingPair.pair];
    if (s){
        s.refCount += 1;
        return NO;
    }
    
    //  添加到订阅列表（不管网络是否正常） 会自动处理网络的断开和链接
    s = [[ScheduleSubMarket alloc] init];
    s.refCount = 1;
    s.tradingPair = tradingPair;
    s.callback = nil;
    s.subscribed = NO;
    s.querying = NO;
    s.monitorOrderStatus = [NSMutableDictionary dictionary];
    s.updateMonitorOrder = NO;
    s.updateLimitOrder = NO;
    s.updateCallOrder = NO;
    s.hasFillOrder = NO;
    s.accumulated_milliseconds = 0;
    s.cfgCallOrderNum = n_callorder;
    s.cfgLimitOrderNum = n_limitorder;
    s.cfgFillOrderNum = n_fillorder;
    [_sub_market_infos setObject:s forKey:tradingPair.pair];
    
    //  执行订阅
    [self _sub_market_notify_core:s];
    
    return YES;
}

- (void)unsub_market_notify:(TradingPair*)tradingPair
{
    assert(tradingPair);
    //  没在订阅中
    ScheduleSubMarket* s = [_sub_market_infos objectForKey:tradingPair.pair];
    if (!s){
        return;
    }
    if (!s.subscribed || !s.callback){
        return;
    }
    
    //  降低引用计数
    s.refCount -= 1;
    if (s.refCount > 0){
        return;
    }
    
    //  引用计数为 0 则移除订阅对象
    [_sub_market_infos removeObjectForKey:tradingPair.pair];
    
    //  连接已断开
    GrapheneConnection* conn = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection];
    if ([conn isClosed]){
        return;
    }
    
    //  取消订阅
    [[[conn.api_db exec:@"unsubscribe_from_market" params:@[s.callback, tradingPair.baseId, tradingPair.quoteId]] then:(^id(id data) {
        NSLog(@"[Unsubscribe] %@/%@ successful.", tradingPair.quoteAsset[@"symbol"], tradingPair.baseAsset[@"symbol"]);
        return nil;
    })] catch:(^id(id error) {
        NSLog(@"[Unsubscribe] %@/%@ successful.", tradingPair.quoteAsset[@"symbol"], tradingPair.baseAsset[@"symbol"]);
        return nil;
    })];
}

- (void)_on_process_sub_market_notify:(NSString*)pair success:(BOOL)success data:(id)data_array
{
    ScheduleSubMarket* s = [_sub_market_infos objectForKey:pair];
    //  已经取消订阅了，在订阅接口还没执行完毕过程中触发通知事件。 fixed Fabric BUG#5 -[ScheduleManager _on_process_sub_market_notify:success:data:]
    if (!s){
        return;
    }
    if (success){
        //  检测处理通知对象：看是否有限价单、抵押单更新、是否有新的成交记录。
        for (id result in data_array) {
            for (id notification in result) {
                if ([notification isKindOfClass:[NSString class]]){
                    //  消失的对象，仅有 id 信息。
                    id oid = notification;
                    id split = [oid componentsSeparatedByString:@"."];
                    if ([split count] >= 3){
                        NSInteger obj_type = [split[1] integerValue];
                        switch (obj_type) {
                            case ebot_limit_order:
                            {
                                s.updateLimitOrder = YES;
                                if ([s.monitorOrderStatus objectForKey:oid]){
                                    s.updateMonitorOrder = YES;
                                    //  TODO:订单成交提示考虑重新设计
                                    [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kTipsOrderClosed", @"订单 #%@ 已成交。"), oid]];
                                }
                            }
                                break;
                            case ebot_call_order:
                                s.updateCallOrder = YES;
                                break;
                            default:
                                NSLog(@"[Unknown] %@: %@", @(obj_type), notification);
                                break;
                        }
                    }else{
                        NSLog(@"Invalid oid: %@", oid);
                    }
                }else{
                    if ([notification isKindOfClass:[NSArray class]]){
                        if ([notification count] == 2){
                            //  有新的 history 对象
                            id op = notification[0];
                            id opcode = op[0];
                            if ([opcode integerValue] == ebo_fill_order){
                                s.hasFillOrder = YES;
                            }else{
                                NSLog(@"%@", notification);
                            }
                        }else{
                            NSLog(@"[Unknown] %@", notification);
                        }
                    }else if ([notification isKindOfClass:[NSDictionary class]]){
                        id oid = [notification objectForKey:@"id"];
                        if (oid){
                            //  对象更新
                            id split = [oid componentsSeparatedByString:@"."];
                            if ([split count] >= 3){
                                NSInteger obj_type = [split[1] integerValue];
                                switch (obj_type) {
                                    case ebot_limit_order:
                                    {
                                        s.updateLimitOrder = YES;
                                        if ([s.monitorOrderStatus objectForKey:oid]){
                                            s.updateMonitorOrder = YES;
                                            //  TODO:订单成交提示考虑重新设计
                                            [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kTipsOrderFilled", @"订单 #%@ 部分成交。"), oid]];
                                        }
                                    }
                                        break;
                                    case ebot_call_order:
                                        s.updateCallOrder = YES;
                                        break;
                                    default:
                                    {
                                        NSLog(@"[Unknown] %@: %@", @(obj_type), notification);
                                    }
                                        break;
                                }
                            }else{
                                NSLog(@"Invalid oid: %@", oid);
                            }
                        }else{
                            NSLog(@"[Unknown] %@", notification);
                        }
                    }
                }
            }
        }
    }else{
        //  连接断开
        //  TODO:fowallet !!! 在重连之后需要重新 subscribe_to_market 。！！！重要
        s.querying = NO;
        s.subscribed = NO;
        //  [统计]
        [OrgUtils logEvents:@"event_subscribe_to_market_disconnect"
                       params:@{@"base":s.tradingPair.baseAsset[@"symbol"], @"quote":s.tradingPair.quoteAsset[@"symbol"]}];
    }
}

- (void)_sub_market_notify_core:(ScheduleSubMarket*)s
{
    //  不用重复订阅
    if (s.subscribed){
        return;
    }
    
    //  网络未连接，暂不订阅。保留订阅对象。
    GrapheneConnection* conn = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection];
    if ([conn isClosed]){
        return;
    }
    
    //  设置 callback
    if (!s.callback){
        id pair = [s.tradingPair.pair copy];
        s.callback = ^(BOOL success, id data){
            [self _on_process_sub_market_notify:pair success:success data:data];
            //  不删除 callback
            return NO;
        };
    }
    
    //  订阅
    TradingPair* tradingPair = s.tradingPair;
    [[[conn.api_db exec:@"subscribe_to_market" params:@[s.callback, tradingPair.baseId, tradingPair.quoteId]] then:(^id(id data) {
        s.subscribed = YES;
        NSLog(@"[Subscribe] %@/%@ successful.", tradingPair.quoteAsset[@"symbol"], tradingPair.baseAsset[@"symbol"]);
        return nil;
    })] catch:(^id(id error) {
        s.subscribed = NO;
        NSLog(@"[Subscribe] %@/%@ failed.", tradingPair.quoteAsset[@"symbol"], tradingPair.baseAsset[@"symbol"]);
        return nil;
    })];
}

#pragma mark- time sub market
- (void)_processSubMarketTimeTick:(NSTimer*)timer dt:(NSTimeInterval)dt
{
    //  没有任何订阅
    if ([_sub_market_infos count] <= 0){
        return;
    }
    
    //  当前网络未连接则不处理。
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    GrapheneConnection* conn = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection];
    BOOL closed = [conn isClosed];
    GrapheneApi* api = conn.api_db;
    
    for (NSString* pair in _sub_market_infos) {
        ScheduleSubMarket* s = _sub_market_infos[pair];
        //  已经在更新中（不处理 tick）
        if (s.querying){
            continue;
        }
        s.accumulated_milliseconds += dt;
        //  网络连接断开，仅累积时间，不执行更新请求。等待网络恢复后请求。
        if (closed){
            continue;
        }
        //  不更新
        if (s.accumulated_milliseconds < kScheduleSubMarketIntervalMin){
            continue;
        }
        //  最大间隔：强制更新所有信息
        if (s.accumulated_milliseconds >= kScheduleSubMarketIntervalMax){
            s.updateMonitorOrder = YES;
            s.updateLimitOrder = YES;
            s.updateCallOrder = YES;
            s.hasFillOrder = YES;
        }
        //  处理更新
        if (s.updateMonitorOrder || s.updateLimitOrder || s.updateCallOrder || s.hasFillOrder){
            //  先更新标记，因为可能在请求更新的过程中，notify又修改了标记了，后续可能判断or覆盖出错。
            BOOL updateMonitorOrder = s.updateMonitorOrder;
            BOOL updateLimitOrder = s.updateLimitOrder;
            //            BOOL updateCallOrder = s.updateCallOrder;//TODO:fowallet
            BOOL hasFillOrder = s.hasFillOrder;
            s.updateMonitorOrder = NO;
            s.updateLimitOrder = NO;
            s.updateCallOrder = NO;
            s.hasFillOrder = NO;
            id p1 = updateLimitOrder && s.cfgLimitOrderNum > 0 ? [chainMgr queryLimitOrders:s.tradingPair number:s.cfgLimitOrderNum] : [NSNull null];
            id p2 = hasFillOrder && s.cfgFillOrderNum > 0 ? [chainMgr queryFillOrderHistory:s.tradingPair number:s.cfgFillOrderNum] : [NSNull null];
            id p3 = hasFillOrder ? [api exec:@"get_ticker" params:@[s.tradingPair.baseId, s.tradingPair.quoteId]] : [NSNull null];
            //  REMARK：monitorOrderStatus 的 Key 是 order_id，Value 是 account_id。
            id account_id = nil;
            if (updateMonitorOrder){
                for (id key in s.monitorOrderStatus) {
                    account_id = [s.monitorOrderStatus objectForKey:key];
                    break;
                }
            }
            id p4 = updateMonitorOrder && account_id ? [chainMgr queryFullAccountInfo:account_id] : [NSNull null];
            //  TODO:fowallet 2.4 p5 updateCallOrder??
            assert(s.cfgCallOrderNum > 0);
            WsPromise* p5 = [chainMgr queryCallOrders:s.tradingPair number:s.cfgCallOrderNum];
            s.querying = YES;
            [[[WsPromise all:@[p1, p2, p3, p4, p5]] then:(^id(id data_array) {
                s.querying = NO;
                //  获取结果
                NSMutableDictionary* result = [NSMutableDictionary dictionary];
                if (updateLimitOrder){
                    [result setObject:data_array[0] forKey:@"kLimitOrders"];
                }
                if (hasFillOrder){
                    [result setObject:data_array[1] forKey:@"kFillOrders"];
                    //  更新 ticker 数据
                    [chainMgr updateTickeraData:s.tradingPair.pair data:data_array[2]];
                }
                if (updateMonitorOrder && account_id){
                    [result setObject:data_array[3] forKey:@"kFullAccountData"];
                }
                [result setObject:data_array[4] forKey:@"kSettlementData"];
                //  更新成功、清除标记、累积时间清零。
                s.accumulated_milliseconds = 0;
                //  通知
                if ([result count] > 0){
                    [[NSNotificationCenter defaultCenter] postNotificationName:kBtsSubMarketNotifyNewData object:nil userInfo:result];
                }
                return nil;
            })] catch:(^id(id error) {
                s.querying = NO;
                //  更新失败、仍然清除标记，但累积时间不从 0 开始。
                s.accumulated_milliseconds /= 2.0f;
                return nil;
            })];
        }
    }
}

@end
