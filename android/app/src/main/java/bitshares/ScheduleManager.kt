package bitshares

import com.btsplusplus.fowallet.kline.TradingPair
import com.fowallet.walletcore.bts.ChainObjectManager
import com.orhanobut.logger.Logger
import org.json.JSONArray
import org.json.JSONObject
import java.util.*

//  Ticker更新时间间隔 最大值和最小值 单位：毫秒
const val kScheduleTickerIntervalMin: Float = 500.0f
const val kScheduleTickerIntervalMax: Float = 300000.0f

//  Ticker更新失败时，时间间隔调整系数，可增大也可降低。
const val kScheduleTickerIntervalErrorFactor: Float = 0.9f

//  Ticker更新数据没变化时，每次递增间隔。
const val kScheduleTickerIntervalStep: Float = 1000.0f

//  [通知]
const val kBtsSubMarketNotifyNewData: String = "kBtsSubMarketNotifyNewData"

//  订阅交易对信息最小更新间隔（即在这个间隔内不管是否有notify都不会更新。）
const val kScheduleSubMarketIntervalMin: Float = 500.0f

// 订阅交易对信息最大更新间隔（即超过这间隔不管是否有notify都会更新。）
const val kScheduleSubMarketIntervalMax: Float = 120000.0f

/**
 * Ticker 任务数据定义
 */
class ScheduleTickerUpdate {

    var quote: String? = null
    var base: String? = null
    var pair: String = ""

    var querying: Boolean = false         //  是否正在执行请求中

    var last_quote_volume: String? = null

    var interval_milliseconds: Long = 0L
    var accumulated_milliseconds: Long = 0L
}

/**
 * SubMarket 订阅交易对消息数据定义
 */
class ScheduleSubMarket {


    var refCount = 0                                                //  K线界面、交易界面都会订阅（需要添加计数）
    var callback: ((Boolean, Any) -> Boolean)? = null
    var tradingPair: TradingPair? = null
    var subscribed: Boolean = false                                 //  是否订阅中

    var querying: Boolean = false                                   //  是否正在执行请求中

    var monitorOrderStatus: MutableMap<String, String>? = null      //  监控指定订单状态

    var updateMonitorOrder: Boolean = false                         // 是否有监控中订单更新（新增、更新、删除）
    var updateLimitOrder: Boolean = false                           // 是否有限价单更新（新增、更新、删除）
    var updateCallOrder: Boolean = false                            // 是否有抵押单更新（新增、更新、删除）
    var hasFillOrder: Boolean = false                               // 是否有新的成交记录

    var accumulated_milliseconds: Long = 0L

    //  部分配置参数
    var cfgCallOrderNum: Int = 0                                    //  [配置] 每次更新时获取限价爆仓单量
    var cfgLimitOrderNum: Int = 0                                   //  [配置] 每次更新时获取限价单数量
    var cfgFillOrderNum: Int = 0                                    //  [配置] 每次更新时获取成交记录数量
}

class ScheduleManager {


    var _timer_per_seconds: Timer? = null                          //  秒精度定时器
    var _ts_last_tick: Long = 0L

    var _task_hash_ticker = mutableMapOf<String, ScheduleTickerUpdate>()

    var _sub_market_infos = mutableMapOf<String, ScheduleSubMarket>()

    //  单例方法
    companion object {
        private var _sharedScheduleManager = ScheduleManager()

        fun sharedScheduleManager(): ScheduleManager {
            return _sharedScheduleManager
        }
    }


    fun startTimer() {
        if (_timer_per_seconds == null) {
            _timer_per_seconds = Timer()
            _timer_per_seconds!!.schedule(object : TimerTask() {
                override fun run() {
                    delay_main {
                        onTimerTick()
                    }
                }
            }, 1000, 3000)
        }
    }

    fun stopTimer() {
        if (_timer_per_seconds != null) {
            _timer_per_seconds!!.cancel()
            _timer_per_seconds = null
        }
    }

    /**
     * 定时器 Tick
     */
    private fun onTimerTick() {

        if (!GrapheneConnectionManager.sharedGrapheneConnectionManager().haveAnyAvailableConnection()) {
            return
        }

        //  REMARK：NSTimer触发时间不太准确，这里自己计算时间间隔。
        val now_ts: Long = java.util.Date().time
        val dt = (now_ts - _ts_last_tick) * 1000
        _ts_last_tick = now_ts

        //  更新 ticker 任务
        _processTickerTimeTick(dt)

        //  更新订阅任务
        _processSubMarketTimeTick(dt)
    }

    /**
     *  [事件] 网络重连成功 TODO:获取重连事件
     */
    fun onWebsocketReconnectSuccess(notification: Any) {
        for ((pair, s) in _sub_market_infos) {

            //  TODO:

            //  重新订阅
            // _sub_market_notify_core(s)

            //  [统计]
            // _sub_market_notify_core()
            // [Answers logCustomEventWithName:@"event_resubscribe_to_market"
            // customAttributes:@{@"base":s.tradingPair.baseAsset[@"symbol"], @"quote":s.tradingPair.quoteAsset[@"symbol"]}];

        }
    }


    /**
     *  根据合并后的市场信息自动添加 or 移除 ticker 更新计划。
     */
    fun autoRefreshTickerScheduleByMergedMarketInfos() {

//    //  TODO:DEBUG only test BTS
//    [self addTickerUpdateSchedule:@"CNY" quote:@"BTS"];
//    return;

        //  标记Hash
        var marker = mutableMapOf<String, Boolean>()

        //  遍历新市场信息
        for (market in ChainObjectManager.sharedChainObjectManager().getMergedMarketInfos()) {
            val base_symbol = market.getJSONObject("base").getString("symbol")
            val group_list = market.getJSONArray("group_list")
            for (i in 0 until group_list.length()) {
                val group_info = group_list.getJSONObject(i)
                val quote_list = group_info.getJSONArray("quote_list")
                for (j in 0 until quote_list.length()) {
                    val quote_symbol = quote_list.getString(j)
                    //  REMARK：pair格式：#{base_symbol}_#{quote_symbol}
                    val pair = String.format("%s_%s", base_symbol, quote_symbol)
                    //  当前schedule没包含该交易对，则添加。
                    val task = _task_hash_ticker["pair"]
                    if (task == null) {
                        addTickerUpdateSchedule(base_symbol, quote_symbol)
                    }
                    marker.set(pair, true)
                }
            }
        }

        //  编译所有ticker的schedule，如果有多余的则删除。
        for (pair in _task_hash_ticker.keys) {
            if (marker[pair] == false) {
                _task_hash_ticker.remove(pair)
            }
        }


    }


    private fun addTickerUpdateSchedule(base_symbol: String?, quote_symbol: String?) {
        assert(base_symbol != null)
        assert(quote_symbol != null)

        val s = ScheduleTickerUpdate()
        s.quote = quote_symbol
        s.base = base_symbol

        //  REMARK：pair格式：#{base_symbol}_#{quote_symbol}
        s.pair = String.format("%s_%s", base_symbol, quote_symbol)
        s.querying = false
        s.last_quote_volume = null
        //  新添加时间隔为0，立即触发。
        s.interval_milliseconds = 0
        s.accumulated_milliseconds = 0

        // 添加到计划Hash
        _task_hash_ticker[s.pair] = s

    }

    fun removeTickerUpdateSchedule(base_symbol: String?, quote_symbol: String?) {
        assert(base_symbol != null)
        assert(quote_symbol != null)
        //  REMARK：pair格式：#{base_symbol}_#{quote_symbol}
        val pair = String.format("%s_%s", base_symbol, quote_symbol)
        _task_hash_ticker.remove(pair)
    }

    fun removeAllTickerSchedule() {
        if (_task_hash_ticker != null) {
            _task_hash_ticker.clear()
        }
    }

    /**
     * 处理异步任务：后台更新交易对的Ticker信息
     */
    private fun _processTickerTimeTick(dt: Long) {
        //  没有任何计划任务
        if (_task_hash_ticker.count() <= 0) {
            return
        }

        //  Todo 当前网络未连接则不处理。
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        for ((key, task) in _task_hash_ticker) {
            //  已经在更新中（不处理 tick）
            if (task.querying) {
                continue
            }
            task.accumulated_milliseconds += dt
            // Todo 网络连接断开，仅累积时间，不执行更新请求。等待网络恢复后请求。
            if (!conn.is_connect()) {
                continue
            }
            if (task.accumulated_milliseconds < task.interval_milliseconds) {
                continue
            }
            // Logger.d(String.format("schedule task update ticker: %s interval: %0.6f", task.pair, task.interval_milliseconds))
            //  设置标记
            task.querying = true
            conn.async_exec_db("get_ticker", jsonArrayfrom(task.base!!, task.quote!!)).then {
                val ticker_data = it as JSONObject
                task.querying = false
                chainMgr.updateTickeraData(task.pair, ticker_data)


                val curr_quote_volume = String.format("%s", ticker_data.getString("quote_volume"))
                val last_quote_volume = task.last_quote_volume
                if (last_quote_volume == null || !last_quote_volume.equals(curr_quote_volume)) {
                    //  ticker有更新（间隔调整到最低）
                    task.interval_milliseconds = kScheduleTickerIntervalMin.toLong()
                    task.accumulated_milliseconds = 0
                    //  设置脏标记
                    TempManager.sharedTempManager().tickerDataDirty = true
                } else {
                    //  ticker没更新（间隔增加）
                    // Logger.d(String.format("schedule task %s curr_quote_volume %s, NO.", task.pair, curr_quote_volume))
                    task.interval_milliseconds = Math.min((task.interval_milliseconds + kScheduleTickerIntervalStep).toLong(), kScheduleTickerIntervalMax.toLong())
                    task.accumulated_milliseconds = 0
                }
                //  记录当前数据
                task.last_quote_volume = curr_quote_volume
                return@then null
            }.catch {
                //  清除标记
                task.querying = false
                //  ticker请求异常，本次更新失败（间隔降低一定比例。）
                task.interval_milliseconds *= kScheduleTickerIntervalErrorFactor.toLong()
                task.accumulated_milliseconds = 0
            }
        }
    }

    /**
     *  监控订单更新
     */
    fun sub_market_monitor_orders(tradingPair: TradingPair, order_ids: JSONArray, account_id: String) {
        val s = _sub_market_infos[tradingPair._pair] ?: return
        assert(s.monitorOrderStatus != null)
        order_ids.forEach<String> { order_id ->
            s.monitorOrderStatus!![order_id!!] = account_id
        }
    }

    fun sub_market_remove_monitor_order(tradingPair: TradingPair?, order_id: String?) {
        assert(tradingPair != null)
        assert(order_id != null)
        val s = _sub_market_infos[tradingPair!!._pair] ?: return
        assert(s.monitorOrderStatus != null)
        s.monitorOrderStatus!!.remove(order_id)

    }

    fun sub_market_remove_all_monitor_orders(tradingPair: TradingPair) {
        assert(tradingPair != null)
        val s = _sub_market_infos[tradingPair._pair] ?: return
        assert(s.monitorOrderStatus != null)
        s.monitorOrderStatus!!.clear()
    }

    fun sub_market_monitor_order_update(tradingPair: TradingPair, updated: Boolean) {
        assert(tradingPair != null)
        val s = _sub_market_infos[tradingPair._pair] ?: return
        s.updateMonitorOrder = updated
    }

    /**
     *  订阅市场的通知信息
     */
    fun sub_market_notify(tradingPair: TradingPair, n_callorder: Int, n_limitorder: Int, n_fillorder: Int): Boolean {
        assert(tradingPair != null)
        var s = _sub_market_infos[tradingPair._pair]
        if (s != null) {
            s.refCount += 1
            return false
        }

        //  添加到订阅列表（不管网络是否正常） 会自动处理网络的断开和链接
        s = ScheduleSubMarket()
        s.refCount = 1
        s.tradingPair = tradingPair
        s.callback = null
        s.subscribed = false
        s.querying = false
        s.monitorOrderStatus = mutableMapOf()
        s.updateMonitorOrder = false
        s.updateLimitOrder = false
        s.updateCallOrder = false
        s.hasFillOrder = false
        s.accumulated_milliseconds = 0
        s.cfgCallOrderNum = n_callorder
        s.cfgLimitOrderNum = n_limitorder
        s.cfgFillOrderNum = n_fillorder
        _sub_market_infos[tradingPair._pair] = s

        //  执行订阅
        _sub_market_notify_core(s)

        return true

    }

    fun unsub_market_notify(tradingPair: TradingPair) {
        //  没在订阅中
        val s = _sub_market_infos[tradingPair._pair] ?: return
        if (!s.subscribed || s.callback == null) {
            return
        }

        //  降低引用计数
        s.refCount -= 1
        if (s.refCount > 0) {
            return
        }

        //  引用计数为 0 则移除订阅对象
        _sub_market_infos.remove(tradingPair._pair)

        //  连接已断开
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        if (!conn.is_connect()) {
            return
        }

        // 取消订阅
        conn.async_exec_db("unsubscribe_from_market", jsonArrayfrom(s.callback!!, tradingPair._baseId, tradingPair._quoteId)).then { data ->
            Logger.d("[Unsubscribe] %s/%s successful.", tradingPair._quoteAsset.getString("symbol"), tradingPair._baseAsset.getString("symbol"))
            return@then null
        }.catch {
            Logger.d("[Unsubscribe] %s/%s successful.", tradingPair._quoteAsset.getString("symbol"), tradingPair._baseAsset.getString("symbol"))
        }
    }

    private fun _on_process_sub_market_notify(pair: String, success: Boolean, data_array_or_errmsg: Any?) {

        //  已经取消订阅了，在订阅接口还没执行完毕过程中触发通知事件。 fixed Fabric BUG#5 -[ScheduleManager _on_process_sub_market_notify:success:data:]
        val s = _sub_market_infos[pair] ?: return

        if (success) {
            val data_array = data_array_or_errmsg as JSONArray
            //  检测处理通知对象：看是否有限价单、抵押单更新、是否有新的成交记录。
            for (result in data_array.forin<JSONArray>()) {
                for (notification in result!!.forin<Any>()) {
                    //  1、字符串类型
                    if (notification is String) {
                        //  消失的对象，仅有 id 信息。
                        val oid = notification
                        val split = oid.split(".")
                        if (split.count() > 3) {
                            val obj_type = split[1].toInt()
                            when (obj_type) {
                                EBitsharesObjectType.ebot_limit_order.value -> {
                                    s.updateLimitOrder = true
                                    if (s.monitorOrderStatus!![oid] != null) {
                                        s.updateMonitorOrder = true
                                        //  TODO:fowallet 多语言 订单成交提示考虑重新设计，没上下文
                                        // [OrgUtils makeToast:[NSString stringWithFormat:@"订单 #%@ 已成交。", oid]];
                                    }
                                }
                                EBitsharesObjectType.ebot_call_order.value -> s.updateCallOrder = true
                                else -> Logger.d(String.format("[Unknown] %s: %s", obj_type, notification))
                            }
                        } else {
//                            Logger.d(Logger.d("Invalid oid: %s", oid))
                        }
                    } else if (notification is JSONArray) {
                        val _notification = notification
                        if (_notification.length() == 2) {
                            //  有新的 history 对象
                            val op = _notification.getJSONArray(0)
                            val opcode = op.getInt(0)
                            if (opcode == EBitsharesOperations.ebo_fill_order.value) {
                                s.hasFillOrder = true
                            } else {
                                Logger.d(String.format("%s", notification))
                            }
                        } else {
                            Logger.d(String.format("[Unknown] %s", notification))
                        }
                    } else if (notification is JSONObject) {
                        val _notification = notification
                        val oid = _notification.optString("id")
                        if (oid != null) {
                            //  对象更新
                            val split = oid.split(".")
                            if (split.count() >= 3) {
                                val obj_type = split[1].toInt()
                                if (obj_type == EBitsharesObjectType.ebot_limit_order.value) {
                                    s.updateLimitOrder = true
                                    if (s.monitorOrderStatus!![oid] != null) {
                                        s.updateMonitorOrder = true
                                        //  TODO:fowallet 多语言 订单成交提示考虑重新设计
                                        // [OrgUtils makeToast:[NSString stringWithFormat:@"订单 #%@ 部分成交。", oid]];
                                    }
                                } else if (obj_type == EBitsharesObjectType.ebot_call_order.value) {
                                    s.updateCallOrder = true
                                } else {
                                    Logger.d("[Unknown] %s: %s", obj_type, notification)
                                }
                            } else {
                                Logger.d(String.format("Invalid oid: %s", oid))
                            }
                        } else {
                            Logger.d(String.format("[Unknown] %@s", notification))
                        }
                    }
                }
            }
        } else {
            //  连接断开
            val errmsg = data_array_or_errmsg as? String
            //  TODO:fowallet !!! 在重连之后需要重新 subscribe_to_market 。！！！重要
            s.querying = false
            s.subscribed = false
            //  [统计]
            btsppLogCustom("event_subscribe_to_market_disconnect",
                    jsonObjectfromKVS("base", s.tradingPair!!._baseAsset.getString("symbol"),
                            "quote", s.tradingPair!!._quoteAsset.getString("symbol")))
        }
    }

    private fun _sub_market_notify_core(s: ScheduleSubMarket) {
        //  不用重复订阅
        if (s.subscribed) {
            return
        }

        //  网络未连接，暂不订阅。保留订阅对象。
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        if (!conn.is_connect()) {
            return
        }

        //  设置 callback
        if (s.callback == null) {
            val pair = s.tradingPair!!._pair
            s.callback = label@{ success, data ->
                _on_process_sub_market_notify(pair, success, data)
                //  不删除 callback
                return@label false
            }
        }

        //  订阅
        val tradingPair = s.tradingPair
        conn.async_exec_db("subscribe_to_market", jsonArrayfrom(s.callback!!, tradingPair!!._baseId, tradingPair._quoteId)).then { data ->
            s.subscribed = true
            Logger.d(String.format("[Subscribe] %s/%s successful.", tradingPair._quoteAsset.getString("symbol"), tradingPair._baseAsset.getString("symbol")))
            return@then null
        }.catch {
            s.subscribed = false
            Logger.d(String.format("[Subscribe] %s/%s failed..", tradingPair._quoteAsset.getString("symbol"), tradingPair._baseAsset.getString("symbol")))
        }
    }

    /**
     * 处理异步任务：订阅的成交历史、盘口深度等信息。
     */
    private fun _processSubMarketTimeTick(dt: Long) {

        // 没有任何订阅
        if (_sub_market_infos.count() <= 0) {
            return
        }

        // 当前网络未连接则不处理
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        for ((pair, s) in _sub_market_infos) {
            //  已经在更新中（不处理 tick）
            if (s.querying) {
                continue
            }
            s.accumulated_milliseconds += dt
            //  网络连接断开，仅累积时间，不执行更新请求。等待网络恢复后请求。
            if (!conn.is_connect()) {
                continue
            }
            //  不更新
            if (s.accumulated_milliseconds < kScheduleTickerIntervalMin) {
                continue
            }
            //  最大间隔：强制更新所有信息
            if (s.accumulated_milliseconds >= kScheduleTickerIntervalMin) {
                s.updateMonitorOrder = true
                s.updateLimitOrder = true
                s.updateCallOrder = true
                s.hasFillOrder = true
            }

            //  处理更新
            if (s.updateMonitorOrder || s.updateLimitOrder || s.updateCallOrder || s.hasFillOrder) {
                //  先更新标记，因为可能在请求更新的过程中，notify又修改了标记了，后续可能判断or覆盖出错。
                val updateMonitorOrder = s.updateMonitorOrder
                val updateLimitOrder = s.updateLimitOrder
                //            BOOL updateCallOrder = s.updateCallOrder;//TODO:fowallet
                val hasFillOrder = s.hasFillOrder
                s.updateMonitorOrder = false
                s.updateLimitOrder = false
                s.updateCallOrder = false
                s.hasFillOrder = false

                val promise_map = JSONObject()
                if (updateLimitOrder && s.cfgLimitOrderNum > 0) {
                    promise_map.put("kLimitOrders", chainMgr.queryLimitOrders(s.tradingPair!!, s.cfgLimitOrderNum))
                }
                if (hasFillOrder && s.cfgLimitOrderNum > 0) {
                    promise_map.put("kFillOrders", chainMgr.queryFillOrderHistory(s.tradingPair!!, s.cfgLimitOrderNum))
                }
                if (hasFillOrder) {
                    promise_map.put("kTickerData", conn.async_exec_db("get_ticker", jsonArrayfrom(s.tradingPair!!._baseId, s.tradingPair!!._quoteId)))
                }
                //  REMARK：monitorOrderStatus 的 Key 是 order_id，Value 是 account_id。
                var account_id: String? = null
                if (updateMonitorOrder) {
                    for (key in s.monitorOrderStatus!!.keys) {
                        account_id = s.monitorOrderStatus!![key]
                        break
                    }
                }
                if (updateMonitorOrder && account_id != null) {
                    promise_map.put("kFullAccountData", chainMgr.queryFullAccountInfo(account_id))
                }
                //  TODO:fowallet 2.4 p5 updateCallOrder??
                assert(s.cfgCallOrderNum > 0)
                promise_map.put("kSettlementData", chainMgr.queryCallOrders(s.tradingPair!!, s.cfgCallOrderNum))
                s.querying = true
                Promise.map(promise_map).then {
                    val hashdata = it as JSONObject
                    s.querying = false
                    //  获取结果
                    val result = JSONObject()
                    if (updateLimitOrder) {
                        result.put("kLimitOrders", hashdata.getJSONObject("kLimitOrders"))
                    }
                    if (hasFillOrder) {
                        result.put("kFillOrders", hashdata.getJSONArray("kFillOrders"))
                        //  更新 ticker 数据
                        chainMgr.updateTickeraData(s.tradingPair!!._pair, hashdata.getJSONObject("kTickerData"))
                    }
                    if (updateMonitorOrder && account_id != null) {
                        result.put("kFullAccountData", hashdata.getJSONObject("kFullAccountData"))
                    }
                    result.put("kSettlementData", hashdata.getJSONObject("kSettlementData"))
                    //  更新成功、清除标记、累积时间清零。
                    s.accumulated_milliseconds = 0
                    //  通知
                    if (result.length() > 0) {
                        NotificationCenter.sharedNotificationCenter().postNotificationName(kBtsSubMarketNotifyNewData, result)
                    }
                    return@then null

                }.catch {
                    s.querying = false
                    //  更新失败、仍然清除标记，但累积时间不从 0 开始。
                    s.accumulated_milliseconds = (s.accumulated_milliseconds / 2.0f).toLong()
                }
            }
        }
    }


}
