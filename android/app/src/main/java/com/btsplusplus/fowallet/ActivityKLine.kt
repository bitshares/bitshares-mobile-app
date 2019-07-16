package com.btsplusplus.fowallet

import android.os.Bundle
import android.os.Handler
import android.os.Message
import android.support.design.widget.TabLayout
import android.view.MotionEvent
import android.view.View
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.kline.MKlineItemData
import com.btsplusplus.fowallet.kline.TradingPair
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_kline.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import kotlin.math.ceil

class ActivityKLine : BtsppActivity() {

    enum class KBottomButtonTag(val value: Int) {
        kBottomButtonTagBuy(0),     //  买
        kBottomButtonTagSell(1),    //  卖
        kBottomButtonTagFav(2),     //  收藏

        kBottomButtonTagMax(3)
    }


    lateinit var _tradingPair: TradingPair

    private var _dataArrayHistory = JSONArray()             //  成交历史
    private var _feedPriceInfo: BigDecimal? = null          //  喂价信息（有的交易对没有喂价）

    private lateinit var _viewKLine: ViewKLine
    private lateinit var _viewCrss: ViewKLineCross
    private lateinit var _viewDeepGraph: ViewDeepGraph
    private lateinit var _viewTradeHistory: ViewTradeHistory
    private lateinit var _viewBidAsk: ViewBidAsk
    private var _notify_handler: Handler? = null

    override fun onResume() {
        super.onResume()
        NotificationCenter.sharedNotificationCenter().addObserver(kBtsSubMarketNotifyNewData, _notify_handler!!)
        _refreshFavButtonStatus()
    }

    override fun onPause() {
        NotificationCenter.sharedNotificationCenter().removeObserver(kBtsSubMarketNotifyNewData, _notify_handler!!)
        super.onPause()
    }

    override fun onDestroy() {
        //  取消所有订阅
        ScheduleManager.sharedScheduleManager().unsub_market_notify(_tradingPair)
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setAutoLayoutContentView(R.layout.activity_kline)

        //  获取参数
        val params = btspp_args_as_JSONArray()
        val base = params.getJSONObject(0)
        val quote = params.getJSONObject(1)

        //  Custom initialization
        _tradingPair = TradingPair().initWithBaseAsset(base, quote)
        _dataArrayHistory = JSONArray()
        _notify_handler = object : Handler() {
            override fun handleMessage(msg: Message?) {
                super.handleMessage(msg)
                if (msg != null) {
                    onSubMarketNotifyNewData(msg)
                }
            }
        }

        _feedPriceInfo = null

        //  设置标题
        findViewById<TextView>(R.id.layout_kline_title).text = "${quote.getString("symbol")}/${base.getString("symbol")}"

        //  获取屏幕宽高
        val sw = Utils.screen_width

        //  UI - 子界面 K线主界面

        //  初始化 K线视图
        _viewKLine = ViewKLine(this, sw, _tradingPair._baseAsset, _tradingPair._quoteAsset)
        _viewKLine.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(px2dip(sw + 16f.dp).toFloat()))
        layout_kline_area_from_kline.addView(_viewKLine)

        //  十字叉
        _viewCrss = ViewKLineCross(this, sw, _tradingPair)
        _viewCrss.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(px2dip(sw + 16f.dp).toFloat()))
        layout_view_cross.addView(_viewCrss)
        //  TODO:交叉引用 是否能释放，测试后删除TODO
        _viewKLine.crossView = _viewCrss
        _viewCrss._kline = _viewKLine

        //  事件 - 返回
        layout_back_from_kline.setOnClickListener { finish() }

        //  深度图
        _viewDeepGraph = ViewDeepGraph(this, sw, _tradingPair)
        _viewDeepGraph.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(px2dip(ceil(sw / 2.0f + 16f.dp).toFloat()).toFloat()))
        layout_depth_area_from_kline.addView(_viewDeepGraph)

        //  子界面 买卖盘口信息
        _viewBidAsk = ViewBidAsk(this).initView(28f, 20, _tradingPair)
        layout_order_book_from_kline.addView(_viewBidAsk)

        //  子界面 成交记录
        _viewTradeHistory = ViewTradeHistory(this).initView(24f, 20, _tradingPair)
        layout_volume_from_kline.addView(_viewTradeHistory)

        //  买
        btn_buy_of_kline.setOnClickListener {
            goTo(ActivityTradeMain::class.java, true, args = jsonArrayfrom(_tradingPair, true))
        }
        //  卖
        btn_sell_of_kline.setOnClickListener {
            goTo(ActivityTradeMain::class.java, true, args = jsonArrayfrom(_tradingPair, false))
        }
        //  收藏
        _refreshFavButtonStatus()
        img_btn_fav_of_kline.setOnClickListener {
            onButtomFavButtonClicked(it)
        }

        setTabListener()

        //  事件 / events
        btn_index.setOnClickListener { _onIndexButtonClicked() }

        setFullScreen()

        //  查询
        _queryInitData()
    }

    private fun _queryInitData() {
        //  请求数据
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()

        chainMgr.queryShortBackingAssetInfos(jsonArrayfrom(_tradingPair._baseId, _tradingPair._quoteId)).then {
            //  更新智能资产信息
            val sba_hash = it as JSONObject
            _tradingPair.refreshCoreMarketFlag(sba_hash)

            //  1、查询K线基本数据
            val parameters = chainMgr.getDefaultParameters()
            val kline_period_ary = parameters.getJSONArray("kline_period_ary")
            val kline_period_default_index = parameters.getInt("kline_period_default")
            assert(kline_period_default_index >= 0 && kline_period_default_index < kline_period_ary.length())
            val default_query_seconds = getDatePeriodSeconds(kline_period_ary.getInt(kline_period_default_index))
            val now: Long = Utils.now_ts()
            val snow = Utils.formatBitsharesTimeString(now)
            val sbgn = Utils.formatBitsharesTimeString(now - default_query_seconds * kBTS_KLINE_MAX_SHOW_CANDLE_NUM)

            val api_conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            val initKdata = api_conn.async_exec_history("get_market_history", jsonArrayfrom(_tradingPair._baseId, _tradingPair._quoteId, default_query_seconds, sbgn, snow))
            val sbgn1 = Utils.formatBitsharesTimeString(now - 86400 * 1)

            //  获取参数
            val n_callorder = parameters.getInt("kline_query_callorder_number")
            val n_limitorder = parameters.getInt("kline_query_limitorder_number")
            val n_fillorder = parameters.getInt("kline_query_fillorder_number")
            assert(n_callorder > 0 && n_limitorder > 0 && n_fillorder > 0)

            //  2、查询最高最低价格等信息
            val initToday = api_conn.async_exec_history("get_market_history", jsonArrayfrom(_tradingPair._baseId, _tradingPair._quoteId, 86400, sbgn1, snow))
            //  3、查询成交记录信息
            val promiseHistory = chainMgr.queryFillOrderHistory(_tradingPair, n_fillorder)
            //  4、查询限价单信息
            val promiseLimitOrders = chainMgr.queryLimitOrders(_tradingPair, n_limitorder)
            //  5、查询爆仓单和喂价信息
            val promiseCallOrders = chainMgr.queryCallOrders(_tradingPair, n_callorder)

            val promise_map = JSONObject()
            promise_map.put("kKlineData", initKdata)
            promise_map.put("kToday", initToday)
            promise_map.put("kHistory", promiseHistory)
            promise_map.put("kLimitOrder", promiseLimitOrders)
            promise_map.put("kSettlementData", promiseCallOrders)

            return@then Promise.map(promise_map).then {
                mask.dismiss()
                val datamap = it as JSONObject
                val settlement_data = datamap.optJSONObject("kSettlementData")
                onQueryFeedPriceInfoResponsed(settlement_data)
                onQueryTodayInfoResponsed(datamap.getJSONArray("kToday"))
                onQueryKdataResponsed(datamap.getJSONArray("kKlineData"))
                onQueryOrderBookResponsed(datamap.getJSONObject("kLimitOrder"), settlement_data)
                onQueryFillOrderHistoryResponsed(datamap.getJSONArray("kHistory"))
                //  继续订阅
                ScheduleManager.sharedScheduleManager().sub_market_notify(_tradingPair, n_callorder, n_limitorder, n_fillorder)
                return@then null
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    private fun _onIndexButtonClicked() {
        val result_promise = Promise()
        goTo(ActivityKLineIndexSetting::class.java, true, args = jsonObjectfromKVS("result_promise", result_promise))
        result_promise.then {
            if (it != null && it as Boolean) {
                _viewKLine.refreshUI()
            }
        }
    }

    private fun _onMoreButtonClicked(tab_more: TabLayout.Tab) {
        val more_list = JSONArray().apply {
            put(JSONObject().apply {
                put("name", resources.getString(R.string.kLabelEkdpt1min))
                put("value", ViewKLine.EKlineDatePeriodType.ekdpt_1m)
            })
            put(JSONObject().apply {
                put("name", resources.getString(R.string.kLabelEkdpt5min))
                put("value", ViewKLine.EKlineDatePeriodType.ekdpt_5m)
            })
            put(JSONObject().apply {
                put("name", resources.getString(R.string.kLabelEkdpt30min))
                put("value", ViewKLine.EKlineDatePeriodType.ekdpt_30m)
            })
            put(JSONObject().apply {
                put("name", resources.getString(R.string.kLabelEkdpt1week))
                put("value", ViewKLine.EKlineDatePeriodType.ekdpt_1w)
            })
        }

        val currentType = _viewKLine.ekdptType
        var defaultIndex = 0
        var idx = 0
        for (item in more_list) {
            val value = item!!.get("value") as ViewKLine.EKlineDatePeriodType
            if (currentType != null && value == currentType) {
                defaultIndex = idx
                break
            }
            ++idx
        }

        ViewDialogNumberPicker(this, null, more_list, "name", defaultIndex) { _index: Int, txt: String ->
            tab_more.text = "$txt${resources.getString(R.string.kLabelEkdptMoreSuffix)}"
            tab_more.tag = more_list.getJSONObject(_index).get("value")
            if (tab_more.isSelected) {
                val current_type = tab_more.tag as ViewKLine.EKlineDatePeriodType
                queryKdata(getDatePeriodSeconds(current_type.value), current_type)
            } else {
                tab_more.select()   //  select will trigger `onTabSelected` event
            }
        }.show()
    }

    private fun setTabListener() {
        //  More Tab
        val tab_more_index = tablayout_of_kline.tabCount - 1
        val tab_more = tablayout_of_kline.getTabAt(tab_more_index)
        if (tab_more != null) {
            (tab_more.view as View).setOnTouchListener { _, event ->
                if (event.action == MotionEvent.ACTION_DOWN) {
                    _onMoreButtonClicked(tab_more)
                }
                return@setOnTouchListener true
            }
        }

        val kline_period_default_index = ChainObjectManager.sharedChainObjectManager().getDefaultParameters().getInt("kline_period_default")
        assert(kline_period_default_index >= 0)
        assert(kline_period_default_index < tab_more_index)

        //  顶部K线tab
        tablayout_of_kline.getTabAt(kline_period_default_index)!!.select()
        tablayout_of_kline!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                val current_type = if (tab.position == tab_more_index) {
                    tab.tag as ViewKLine.EKlineDatePeriodType
                } else {
                    tablayout_of_kline.getTabAt(tab_more_index)!!.text = resources.getString(R.string.kLabelEkdptBtnMore)
                    when (tab.position) {
                        0 -> ViewKLine.EKlineDatePeriodType.ekdpt_timeline
                        1 -> ViewKLine.EKlineDatePeriodType.ekdpt_15m
                        2 -> ViewKLine.EKlineDatePeriodType.ekdpt_1h
                        3 -> ViewKLine.EKlineDatePeriodType.ekdpt_4h
                        else -> ViewKLine.EKlineDatePeriodType.ekdpt_1d
                    }
                }
                queryKdata(getDatePeriodSeconds(current_type.value), current_type)
            }

            override fun onTabUnselected(tab: TabLayout.Tab) {
                //tab未被选择的时候回调
            }

            override fun onTabReselected(tab: TabLayout.Tab) {
                //tab重新选择的时候回调
            }
        })

        //  深度和成交tab
        tablayout_depth_of_kline!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                if (tab.position == 0) {
                    layout_depth_area_title_from_kline.visibility = View.VISIBLE
                    layout_depth_area_from_kline.visibility = View.VISIBLE
                    layout_order_book_from_kline.visibility = View.VISIBLE
                    layout_volume_from_kline.visibility = View.GONE
                }
                if (tab.position == 1) {
                    layout_depth_area_title_from_kline.visibility = View.GONE
                    layout_depth_area_from_kline.visibility = View.GONE
                    layout_order_book_from_kline.visibility = View.GONE
                    layout_volume_from_kline.visibility = View.VISIBLE
                }
            }

            override fun onTabUnselected(tab: TabLayout.Tab) {
                //tab未被选择的时候回调
            }

            override fun onTabReselected(tab: TabLayout.Tab) {
                //tab重新选择的时候回调
            }
        })
    }

    /**
     * 接收到订阅消息
     */
    private fun onSubMarketNotifyNewData(msg: Message) {
        val userinfo = msg.obj as? JSONObject
        if (userinfo == null) {
            return
        }
        val settlement_data = userinfo.optJSONObject("kSettlementData")
        //  更新喂价信息
        onQueryFeedPriceInfoResponsed(settlement_data)
        //  更新限价单
        onQueryOrderBookResponsed(userinfo.optJSONObject("kLimitOrders"), settlement_data)
        //  更新成交历史
        val fillOrders = userinfo.optJSONArray("kFillOrders")
        if (fillOrders != null) {
            _refreshCurrentTickerData()
            onQueryFillOrderHistoryResponsed(fillOrders)
        }
    }

    private fun onQueryFeedPriceInfoResponsed(settlement_data: JSONObject?) {
        //  计算喂价（可能为 nil）
        _feedPriceInfo = settlement_data?.opt("feed_price_market") as? BigDecimal
        //  显示喂价
        if (_feedPriceInfo != null) {
            field_feedprice.visibility = View.VISIBLE
            label_txt_feed_price_value.text = _feedPriceInfo!!.toPlainString()
        } else {
            field_feedprice.visibility = View.INVISIBLE
        }
    }


    private fun onQueryTodayInfoResponsed(one_kdata: JSONArray?) {
        if (one_kdata != null && one_kdata.length() > 0) {
            val model = MKlineItemData.parseData(
                    one_kdata.getJSONObject(0),
                    null,
                    _tradingPair._baseId,
                    _tradingPair._basePrecision,
                    _tradingPair._quotePrecision,
                    null,
                    null)
            label_txt_high_value.text = "${model.nPriceHigh}"
            label_txt_low_value.text = "${model.nPriceLow}"
            label_txt_24h_value.text = "${model.n24Vol}"
            _refreshCurrentTickerData()
        } else {
            label_txt_24h_value.text = "0"
        }
    }

    private fun _refreshCurrentTickerData() {
        var latest = "--"
        var percent_change = "0"
        val ticker_data = ChainObjectManager.sharedChainObjectManager().getTickerData(_tradingPair._baseAsset.getString("symbol"), _tradingPair._quoteAsset.getString("symbol"))
        if (ticker_data != null) {
            latest = OrgUtils.formatFloatValue(ticker_data.getString("latest").toDouble(), _tradingPair._basePrecision)
            percent_change = ticker_data.getString("percent_change")
        }
        label_txt_latest_price.text = latest
        val percent = percent_change.toDouble()
        if (percent > 0) {
            label_txt_latest_price_percent.text = "+${percent_change}%"
            label_txt_latest_price_percent.setTextColor(this.resources.getColor(R.color.theme01_buyColor))
            label_txt_latest_price.setTextColor(this.resources.getColor(R.color.theme01_buyColor))
        } else if (percent < 0) {
            label_txt_latest_price_percent.text = "${percent_change}%"
            label_txt_latest_price_percent.setTextColor(this.resources.getColor(R.color.theme01_sellColor))
            label_txt_latest_price.setTextColor(this.resources.getColor(R.color.theme01_sellColor))
        } else {
            label_txt_latest_price_percent.text = "${percent_change}%"
            label_txt_latest_price_percent.setTextColor(this.resources.getColor(R.color.theme01_zeroColor))
            label_txt_latest_price.setTextColor(this.resources.getColor(R.color.theme01_zeroColor))
        }
    }

    private fun onQueryKdataResponsed(data_array: JSONArray) {
        //  TODO:fowallet 这个返回的数据不包含 成交量为 0的数据，如果24h量为了，这里面没显示。
        //  TODO:fowallet !!!!
        _viewKLine.refreshCandleLayerPrepare(data_array)
    }

    private fun onQueryOrderBookResponsed(normal_order_book: JSONObject?, settlement_data: JSONObject?) {
        //  订阅市场返回的数据可能为 nil。
        if (normal_order_book == null) {
            return
        }
        //  初始化显示精度
        _tradingPair.dynamicUpdateDisplayPrecision(normal_order_book)
        // 刷新深度图和盘口信息
        val merged_order_book = OrgUtils.mergeOrderBook(normal_order_book, settlement_data)
        _viewDeepGraph.refreshDeepGraph(merged_order_book)
        // 刷新盘口信息
        _viewBidAsk.refreshWithData(merged_order_book)
    }

    private fun onQueryFillOrderHistoryResponsed(data_array: JSONArray?) {
        //  订阅市场返回的数据可能为 nil。
        if (data_array == null) {
            return
        }
        _dataArrayHistory = JSONArray()
        _dataArrayHistory.putAll(data_array)
        _viewTradeHistory.refreshWithData(this, data_array)
    }

    fun queryKdata(seconds: Int, ekdptType: ViewKLine.EKlineDatePeriodType) {
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()

        val now = Utils.now_ts()
        val snow = Utils.formatBitsharesTimeString(now)
        val sbgn = Utils.formatBitsharesTimeString(now - seconds * kBTS_KLINE_MAX_SHOW_CANDLE_NUM)
        val api_conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        val api_history = api_conn.async_exec_history("get_market_history", jsonArrayfrom(_tradingPair._baseId, _tradingPair._quoteId, seconds, sbgn, snow))
        api_history.then {
            val data = it as JSONArray
            mask.dismiss()
            _viewKLine.ekdptType = ekdptType
            onQueryKdataResponsed(data)
            return@then null
        }.catch {
            mask.dismiss()
        }
    }

    /**
     *  获取K线时间周期对应的秒数
     */
    fun getDatePeriodSeconds(ekdpt: Int): Int {
        when (ekdpt) {
            ViewKLine.EKlineDatePeriodType.ekdpt_timeline.value -> return 60 //  分时图就是分钟线的收盘价连接的点。
            ViewKLine.EKlineDatePeriodType.ekdpt_1m.value -> return 60
            ViewKLine.EKlineDatePeriodType.ekdpt_5m.value -> return 300
            ViewKLine.EKlineDatePeriodType.ekdpt_15m.value -> return 900
            ViewKLine.EKlineDatePeriodType.ekdpt_30m.value -> return 1800
            ViewKLine.EKlineDatePeriodType.ekdpt_1h.value -> return 3600
            ViewKLine.EKlineDatePeriodType.ekdpt_4h.value -> return 14400
            ViewKLine.EKlineDatePeriodType.ekdpt_1d.value -> return 86400
            ViewKLine.EKlineDatePeriodType.ekdpt_1w.value -> return 604800
        }
        //  not reached...
        assert(false)
        return 0
    }

    /**
     * 刷新收藏按钮状态，如果在交易界面收藏了，则回到K线界面需要刷新，反之依然。
     */
    private fun _refreshFavButtonStatus() {
        if (AppCacheManager.sharedAppCacheManager().is_fav_market(_tradingPair._quoteAsset.getString("symbol"), _tradingPair._baseAsset.getString("symbol"))) {
            img_btn_fav_of_kline.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
        } else {
            img_btn_fav_of_kline.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        }
    }

    /**
     *  (private) 事件 - 收藏按钮点击（参考交易界面右上角按钮对应逻辑）
     */
    private fun onButtomFavButtonClicked(v: View) {
        val v = v as ImageButton
        assert(v.tag == KBottomButtonTag.kBottomButtonTagFav.value)

        val pAppCache = AppCacheManager.sharedAppCacheManager()

        val quote_symbol = _tradingPair._quoteAsset.getString("symbol")
        val base_symbol = _tradingPair._baseAsset.getString("symbol")
        if (pAppCache.is_fav_market(quote_symbol, base_symbol)) {
            //  取消自选、灰色五星、提示信息
            pAppCache.remove_fav_markets(quote_symbol, base_symbol)
            v.setColorFilter(resources.getColor(R.color.theme01_textColorNormal))
            showToast(resources.getString(R.string.kTipsAddFavDelete))
            //  [统计]
            btsppLogCustom("event_market_remove_fav", jsonObjectfromKVS("base", base_symbol, "quote", quote_symbol))
        } else {
            //  添加自选、高亮五星、提示信息
            pAppCache.set_fav_markets(quote_symbol, base_symbol)
            v.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
            showToast(resources.getString(R.string.kTipsAddFavSuccess))
            //  [统计]
            btsppLogCustom("event_market_add_fav", jsonObjectfromKVS("base", base_symbol, "quote", quote_symbol))
        }
        pAppCache.saveFavMarketsToFile()

        //  REMARK：自选列表需要更新
        TempManager.sharedTempManager().favoritesMarketDirty = true
    }

    private fun px2dip(pxValue: Float): Int {
        val scale = resources.displayMetrics.density
        return (pxValue / scale + 0.5f).toInt()
    }


}
