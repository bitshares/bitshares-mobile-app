package com.btsplusplus.fowallet

import android.os.Bundle
import android.os.Handler
import android.os.Message
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_main.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityTradeMain : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    lateinit var _tradingPair: TradingPair
    private var _defaultSelectBuy: Boolean = true
    private var _haveAccountOnInit: Boolean = true
    private var _notify_handler: Handler? = null

    override fun onResume() {
        super.onResume()
        NotificationCenter.sharedNotificationCenter().addObserver(kBtsSubMarketNotifyNewData, _notify_handler!!)
        //  REMARK：考虑在这里刷新登录状态，用登录vc的callback会延迟，会看到文字变化。
        onRefreshLoginStatus()
        //  REMARK：用户在 订单管理 界面取消了订单，则这里需要刷新。
        onRefreshUserLimitOrderChanged()
    }

    override fun onPause() {
        NotificationCenter.sharedNotificationCenter().removeObserver(kBtsSubMarketNotifyNewData, _notify_handler!!)
        super.onPause()
    }

    override fun onDestroy() {
        //  取消所有订阅
        ScheduleManager.sharedScheduleManager().sub_market_remove_all_monitor_orders(_tradingPair)
        ScheduleManager.sharedScheduleManager().unsub_market_notify(_tradingPair)
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_main)

        //  获取参数
        val params = btspp_args_as_JSONArray()
        _tradingPair = params.get(0) as TradingPair
        _defaultSelectBuy = params.getBoolean(1)
        //  确保智能资产信息已经初始化
        assert(_tradingPair._bCoreMarketInited)
        //  REMARK：在初始化的时候判断帐号信息
        _haveAccountOnInit = WalletManager.sharedWalletManager().isWalletExist()
        _notify_handler = object : Handler() {
            override fun handleMessage(msg: Message?) {
                super.handleMessage(msg)
                if (msg != null) {
                    onSubMarketNotifyNewData(msg)
                }
            }
        }

        //  返回
        button_back_for_main.setOnClickListener { finish() }

        //  标题
        title_of_main.text = "${_tradingPair._quoteAsset.getString("symbol")}/${_tradingPair._baseAsset.getString("symbol")}"

        //  收藏按钮
        if (AppCacheManager.sharedAppCacheManager().is_fav_market(_tradingPair._quoteAsset.getString("id"), _tradingPair._baseAsset.getString("id"))) {
            btn_fav.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
        } else {
            btn_fav.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        }
        btn_fav.setOnClickListener { _onFavClicked() }

        //  动态初始化TabItem
        findViewById<TabLayout>(R.id.tablayout_of_main_buy_and_sell).let { tab ->
            tab.addTab(tab.newTab().apply {
                text = resources.getString(R.string.kLabelTitleBuy)
            })
            tab.addTab(tab.newTab().apply {
                text = resources.getString(R.string.kLabelTitleSell)
            })
            if (!SettingManager.sharedSettingManager().isEnableHorTradeUI()) {
                //  当前委托 - 竖版界面才存在
                tab.addTab(tab.newTab().apply {
                    text = resources.getString(R.string.kLabelOpenOrders)
                })
            }
            if (_tradingPair._isCoreMarket) {
                tab.addTab(tab.newTab().apply {
                    text = resources.getString(R.string.kVcOrderPageSettleOrders)
                })
            }
        }
        //  添加 fargments
        setFragments()
        //  设置 viewPager 并配置滚动速度
        setViewPager(if (_defaultSelectBuy) 0 else 1, R.id.view_pager_of_main_buy_and_sell, R.id.tablayout_of_main_buy_and_sell, fragmens)
        //  监听 tab 并设置选中 item
        setTabListener(R.id.tablayout_of_main_buy_and_sell, R.id.view_pager_of_main_buy_and_sell) { pos ->
            fragmens[pos].let {
                if (it is FragmentOrderCurrent) {
                    it.onControllerPageChanged()
                } else if (it is FragmentOrderHistory) {
                    it.querySettlementOrders(tradingPair = _tradingPair)
                }
            }
        }
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  请求数据
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        //  优先查询智能背书资产信息（之后才考虑是否查询喂价、爆仓单等信息）
        _tradingPair.queryBitassetMarketInfo().then {
            //  获取参数
            val parameters = chainMgr.getDefaultParameters()
            val n_callorder = parameters.getInt("trade_query_callorder_number")
            val n_limitorder = parameters.getInt("trade_query_limitorder_number")
            val n_fillorder = parameters.getInt("trade_query_fillorder_number")
            assert(n_callorder > 0 && n_limitorder > 0 && n_fillorder > 0)

            val promise_map = JSONObject()

            val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            val walletMgr = WalletManager.sharedWalletManager()
            if (walletMgr.isWalletExist()) {
                promise_map.put("kUserLimit", chainMgr.queryUserLimitOrders(walletMgr.getWalletAccountInfo()!!.getJSONObject("account").getString("id")))
            }
            promise_map.put("kLimitOrder", chainMgr.queryLimitOrders(_tradingPair, n_limitorder))
            promise_map.put("kTickerData", conn.async_exec_db("get_ticker", jsonArrayfrom(_tradingPair._baseId, _tradingPair._quoteId)))
            promise_map.put("kFee", chainMgr.queryFeeAssetListDynamicInfo())    //  查询手续费兑换比例、手续费池等信息
            promise_map.put("kSettlementData", chainMgr.queryCallOrders(_tradingPair, n_callorder))
            if (!SettingManager.sharedSettingManager().isEnableHorTradeUI()) {
                promise_map.put("kFillOrders", chainMgr.queryFillOrderHistory(_tradingPair, n_fillorder))
            }

            return@then Promise.map(promise_map).then {
                mask.dismiss()
                onInitPromiseResponse(it as JSONObject)
                //  继续订阅
                ScheduleManager.sharedScheduleManager().sub_market_notify(_tradingPair, n_callorder, n_limitorder, n_fillorder)
                return@then null
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    /**
     * 接收到订阅消息
     */
    private fun onSubMarketNotifyNewData(msg: Message) {
        val userinfo = msg.obj as? JSONObject
        if (userinfo == null) {
            return
        }
        //  过滤其他的交易对
        val kCurrentPair = userinfo.optString("kCurrentPair", null)
        if (kCurrentPair != null && kCurrentPair != _tradingPair._pair) {
            return
        }
        //  更新限价单
        val settlement_data = userinfo.optJSONObject("kSettlementData")
        onQueryOrderBookResponse(userinfo.optJSONObject("kLimitOrders"), settlement_data)
        //  更新成交历史和Ticker
        onQueryFillOrderHistoryResponsed(userinfo.optJSONArray("kFillOrders"))
        //  更新帐号信息
        val fullUserData = userinfo.optJSONObject("kFullAccountData")
        if (fullUserData != null) {
            onFullAccountInfoResponsed(fullUserData)
        }
    }

    /**
     * 收藏按钮点击事件
     */
    private fun _onFavClicked() {
        VcUtils.processMyFavPairStateChanged(this, _tradingPair._quoteAsset, _tradingPair._baseAsset, associated_view = btn_fav)
    }

    /**
     * 处理初始化返回数据
     */
    private fun onInitPromiseResponse(datamap: JSONObject) {
        //  1、更新账户所有资产和当前委托信息
        val full_account_data = datamap.optJSONObject("kUserLimit")
        onFullAccountInfoResponsed(full_account_data)

        //  2、更新 ticker 数据
        val ticker_data = datamap.getJSONObject("kTickerData")
        ChainObjectManager.sharedChainObjectManager().updateTickeraData(_tradingPair._baseId, _tradingPair._quoteId, ticker_data)
        //  设置脏标记
        TempManager.sharedTempManager().tickerDataDirty = true
        onQueryTickerDataResponse(ticker_data)

        //  3、更新限价单（普通盘口+爆仓单）
        onQueryOrderBookResponse(datamap.getJSONObject("kLimitOrder"), datamap.optJSONObject("kSettlementData"))

        //  4、更新成交记录
        onQueryFillOrderHistoryResponsed(datamap.optJSONArray("kFillOrders"))
    }

    /**
     * (private) 事件 - 处理登录成功事件
     */
    private fun onRefreshLoginStatus() {
        if (fragmens.size <= 0) {
            return
        }

        //  REMARK：界面创建就已经有帐号了，则不用刷新了。只有从该界面里进行登录才需要刷新。
        if (_haveAccountOnInit) {
            return
        }

        //  未登录
        if (!WalletManager.sharedWalletManager().isWalletExist()) {
            return
        }

        //  在交易界面完成了登录过程

        //  a、刷新可用余额
        onFullAccountInfoResponsed(WalletManager.sharedWalletManager().getWalletAccountInfo()!!)

        //  b、刷新登录按钮状态
        fragmens.forEach {
            if (it is FragmentTradeMainPage) {
                it.onRefreshLoginStatus()
            } else if (it is FragmentTradeBuyOrSell) {
                it.onRefreshLoginStatus()
            }
        }
    }

    /**
     * (private) 事件 - 刷新用户订单信息
     */
    private fun onRefreshUserLimitOrderChanged() {
        //  订单信息发生变化了
        if (TempManager.sharedTempManager().userLimitOrderDirty) {
            TempManager.sharedTempManager().userLimitOrderDirty = false
            //  未登录
            val walletMgr = WalletManager.sharedWalletManager()
            if (!walletMgr.isWalletExist()) {
                return
            }
            //  刷新
            val account_id = walletMgr.getWalletAccountInfo()!!.getJSONObject("account").getString("id")
            val full_account_data = ChainObjectManager.sharedChainObjectManager().getFullAccountDataFromCache(account_id)
            if (full_account_data != null) {
                onFullAccountInfoResponsed(full_account_data)
            }
        }
    }

    fun onFullAccountInfoResponsed(full_account_data: JSONObject?) {
        fragmens.forEach {
            if (it is FragmentTradeMainPage) {
                it.onFullAccountDataResponsed(full_account_data)
            } else if (it is FragmentTradeBuyOrSell) {
                it.onFullAccountDataResponsed(full_account_data)
            }
        }
    }

    private fun onQueryTickerDataResponse(ticker_data: JSONObject) {
        fragmens.forEach {
            if (it is FragmentTradeMainPage) {
                it.onQueryTickerDataResponse(ticker_data)
            } else if (it is FragmentTradeBuyOrSell) {
                it.onQueryTickerDataResponse(ticker_data)
            }
        }
    }

    private fun onQueryFillOrderHistoryResponsed(data: JSONArray?) {
        //  订阅市场返回的数据可能为 nil。横板交易界面初始化时也会返回nil。
        if (data != null) {
            fragmens.forEach {
                if (it is FragmentTradeMainPage) {
                    it.onQueryFillOrderHistoryResponsed(data)
                } else if (it is FragmentTradeBuyOrSell) {
                    it.onQueryFillOrderHistoryResponsed(data)
                }
            }
        }
    }

    private fun onQueryOrderBookResponse(normal_order_book: JSONObject?, settlement_data: JSONObject?) {
        if (normal_order_book != null) {
            val merged_order_book = OrgUtils.mergeOrderBook(normal_order_book, settlement_data)
            fragmens.forEach {
                if (it is FragmentTradeMainPage) {
                    it.onQueryOrderBookResponse(merged_order_book)
                } else if (it is FragmentTradeBuyOrSell) {
                    it.onQueryOrderBookResponse(merged_order_book)
                }
            }
        }
    }

    private fun setFragments() {
        if (!SettingManager.sharedSettingManager().isEnableHorTradeUI()) {
            //  竖版 买卖界面 + 委托界面
            fragmens.add(FragmentTradeBuyOrSell().initialize(jsonArrayfrom(true, _tradingPair)))
            fragmens.add(FragmentTradeBuyOrSell().initialize(jsonArrayfrom(false, _tradingPair)))
            fragmens.add(FragmentOrderCurrent().initialize(JSONObject().apply {
                put("full_account_data", null)
                put("tradingPair", _tradingPair)
                put("filter", true)
            }))
        } else {
            //  横板 买卖界面
            fragmens.add(FragmentTradeMainPage().initialize(jsonArrayfrom(true, _tradingPair)))
            fragmens.add(FragmentTradeMainPage().initialize(jsonArrayfrom(false, _tradingPair)))
        }

        //  清算单界面（横板竖版都有）
        if (_tradingPair._isCoreMarket) {
            fragmens.add(FragmentOrderHistory().initialize(JSONObject().apply {
                put("isSettlementsOrder", true)
            }))
        }
    }

}
