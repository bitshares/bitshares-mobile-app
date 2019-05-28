package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.v4.app.Fragment
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_index_markets.*
import org.json.JSONObject
import java.util.*
import kotlin.collections.ArrayList

class ActivityIndexMarkets : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()

    private var _tickerRefreshTimer: Timer? = null

    /**
     * 重载 - 返回键按下
     */
    override fun onBackPressed() {
        goHome()
    }

    //  事件：将要进入后台
    override fun onPause() {
        super.onPause()
        //  停止计时器
        stopTickerRefreshTimer()
        //  处理逻辑
        AppCacheManager.sharedAppCacheManager().saveToFile()
    }

    //  事件：已经进入前台
    override fun onResume() {
        super.onResume()
        //  回到前台检测是否需要重新连接。
        GrapheneConnectionManager.sharedGrapheneConnectionManager().reconnect_all()
        //  自选市场可能发生变化，重新加载。
        onRefreshFavoritesMarket()
        //  自定义交易对发生变化，重新加载。
        onRefreshCustomMarket()
        //  添加Ticker刷新定时器
        startTickerRefreshTimer()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_index_markets, navigationBarColor = R.color.theme01_tabBarColor)

        // 设置 fragment
        setFragments()
        setViewPager(1, R.id.view_pager, R.id.tablayout, fragmens)

        // 监听 tab 并设置选中 item
        setTabListener(R.id.tablayout, R.id.view_pager)

        // 监听 + 按钮事件
        setAddBtnListener()

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 设置底部导航栏样式
        setBottomNavigationStyle(0)
    }

    /**
     * 启动定时器：刷新Ticker数据用
     */
    private fun startTickerRefreshTimer() {
        if (_tickerRefreshTimer == null) {
            _tickerRefreshTimer = Timer()
            _tickerRefreshTimer!!.schedule(object : TimerTask() {
                override fun run() {
                    delay_main {
                        onTimerTickerRefresh()
                    }
                }
            }, 300, 1000)
        }
    }

    /**
     * 停止定时器
     */
    private fun stopTickerRefreshTimer() {
        if (_tickerRefreshTimer != null) {
            _tickerRefreshTimer!!.cancel()
            _tickerRefreshTimer = null
        }
    }

    /**
     * 定时器 tick 执行逻辑
     */
    private fun onTimerTickerRefresh() {
        if (TempManager.sharedTempManager().tickerDataDirty) {
            TempManager.sharedTempManager().tickerDataDirty = false
            for (fragment in fragmens) {
                val fr = fragment as FragmentMarketInfo
                fr.onRefreshTickerData()
            }
        }
    }

    /**
     *  (private) 事件 - 刷新自选(关注、收藏)市场
     */
    private fun onRefreshFavoritesMarket() {
        if (TempManager.sharedTempManager().favoritesMarketDirty) {
            //  清除标记
            TempManager.sharedTempManager().favoritesMarketDirty = false
            //  刷新
            for (fragment in fragmens) {
                val fr = fragment as FragmentMarketInfo
                fr.onRefreshFavoritesMarket()
            }
        }
    }

    /**
     *  (private) 事件 - 刷新自定义交易对市场 同时刷新收藏列表（因为变更自定义交易对，可能导致收藏失效。）
     */
    private fun onRefreshCustomMarket() {
        if (TempManager.sharedTempManager().customMarketDirty) {
            //  重新构建各市场分组信息
            ChainObjectManager.sharedChainObjectManager().buildAllMarketsInfos()
            //  清除标记
            TempManager.sharedTempManager().customMarketDirty = false
            //  刷新
            for (fragment in fragmens) {
                val fr = fragment as FragmentMarketInfo
                fr.onRefreshCustomMarket()
                fr.onRefreshFavoritesMarket()
            }
            //  自定义交易对发生变化，重新刷新ticker更新任务。
            ScheduleManager.sharedScheduleManager().autoRefreshTickerScheduleByMergedMarketInfos()
        }
    }

    fun getTitleStringArray(): MutableList<String> {
        var ary = mutableListOf<String>(resources.getString(R.string.kLabelMarketFavorites))
        ary.addAll(ChainObjectManager.sharedChainObjectManager().getMergedMarketInfos().map { market: JSONObject ->
            market.getJSONObject("base").getString("name")
        })
        return ary
    }

    fun getTitleDefaultSelectedIndex(): Int {
        //  REMARK：默认选中第二个市场（第一个是自选市场）
        return 2
    }

    private fun setAddBtnListener() {
        button_add.setOnClickListener {
            goTo(ActivityAddAssetPairsBase::class.java, true)
        }
    }

    private fun setFragments() {
        //  REMARK：marketInfo 参数为 nil，说明为自选市场。
        fragmens.add(FragmentMarketInfo().initialize(null))
        //  非自选市场
        ChainObjectManager.sharedChainObjectManager().getMergedMarketInfos().forEach { market: JSONObject ->
            fragmens.add(FragmentMarketInfo().initialize(market))
        }
    }

}

