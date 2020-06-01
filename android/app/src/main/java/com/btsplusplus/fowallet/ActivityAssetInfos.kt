package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_asset_infos.*
import org.json.JSONArray
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityAssetInfos : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private var _curr_select_index = 0
    private lateinit var _curr_asset: JSONObject

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_asset_infos)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  初始化默认资产
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val list = chainMgr.getMainSmartAssetList()
        assert(list.length() > 0)
        _curr_asset = chainMgr.getAssetBySymbol(list.first<String>()!!)

        //  动态初始化TabItem
        val self = this
        findViewById<TabLayout>(R.id.tablayout_of_diya_ranking).let { tab ->
            tab.addTab(tab.newTab().apply {
                text = self.resources.getString(R.string.kVcSmartPageTitleRank)
            })
            tab.addTab(tab.newTab().apply {
                text = self.resources.getString(R.string.kVcSmartPageTitleFeed)
            })
            tab.addTab(tab.newTab().apply {
                text = self.resources.getString(R.string.kVcOrderPageSettleOrders)
            })
        }

        //  事件 - 切换资产
        btn_select_assets.setOnClickListener { onSelectAssetClicked() }

        //  事件 - 返回
        layout_back_from_diya_ranking.setOnClickListener { finish() }

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_diya_ranking
        view_pager = view_pager_of_diya_ranking

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()

        //  开始请求
        queryCurrentPage()
    }

    /**
     * 选择资产
     */
    private fun onSelectAssetClicked() {
        val self = this

        //  获取配置的默认列表
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val asset_list = JSONArray()
        chainMgr.getMainSmartAssetList().forEach<String> { symbol ->
            asset_list.put(chainMgr.getAssetBySymbol(symbol!!))
        }

        //  添加自定义选项
        asset_list.put(JSONObject().apply {
            put("symbol", self.resources.getString(R.string.kVcAssetMgrCellValueSmartBackingAssetCustom))
            put("is_custom", true)
        })

        //  选择列表
        ViewSelector.show(this, "", asset_list, "symbol") { index: Int, result: String ->
            val select_item = asset_list.getJSONObject(index)
            if (select_item.isTrue("is_custom")) {
                //  自定义资产
                TempManager.sharedTempManager().set_query_account_callback { last_activity, asset_info ->
                    last_activity.goTo(ActivityAssetInfos::class.java, true, back = true)
                    processSelectNewAsset(asset_info)
                }
                goTo(ActivityAccountQueryBase::class.java, true, args = JSONObject().apply {
                    put("kSearchType", ENetworkSearchType.enstAssetSmart)
                    put("kTitle", self.resources.getString(R.string.kVcTitleSearchAssets))
                })
            } else {
                //  从列表中选择结果
                processSelectNewAsset(select_item)
            }
        }
    }

    private fun processSelectNewAsset(newAsset: JSONObject) {
        //   选择的就是当前资产，直接返回。
        if (newAsset.getString("id") == _curr_asset.getString("id")) {
            return
        }

        //  更新缓存
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        chainMgr.appendAssetCore(newAsset)

        //  更新资产
        _curr_asset = newAsset
        fragmens.forEach {
            if (it is FragmentMarginRanking) {
                it.setCurrentAsset(_curr_asset)
            } else if (it is FragmentFeedPrice) {
                it.setCurrentAsset(_curr_asset)
            }
        }

        //  刷新当前页面
        queryCurrentPage()
    }

    private fun genSettlementOrderTradingPair(curr_asset: JSONObject): TradingPair {
        //  REMARK：构造清算单界面所需 *TradingPair* 参数。
        //  注：这里构造的并非完整的 TradingPair 对象，清算单界面目前只需要 baseAsset 和 smartAssetId 两个数据，这里只确保这两个参数正确。
        val tradingPair = TradingPair().initWithBaseAsset(curr_asset, curr_asset)
        tradingPair._smartAssetId =  curr_asset.getString("id")
        tradingPair._sbaAssetId = curr_asset.getString("id")
        tradingPair._isCoreMarket = true
        return tradingPair
    }

    private fun queryCurrentPage() {
        btsppLogTrack("asset info query: index: $_curr_select_index, curr asset: ${_curr_asset.getString("id")}")
        fragmens[_curr_select_index].let {
            if (it is FragmentOrderHistory) {
                it.querySettlementOrders(tradingPair = genSettlementOrderTradingPair(_curr_asset))
            } else if (it is BtsppFragment) {
                it.onControllerPageChanged()
            }
        }
    }

    private fun setViewPager() {
        view_pager!!.adapter = ViewPagerAdapter(super.getSupportFragmentManager(), fragmens)
        val f: Field = ViewPager::class.java.getDeclaredField("mScroller")
        f.isAccessible = true
        val vpc = ViewPagerScroller(view_pager!!.context, OvershootInterpolator(0.6f))
        f.set(view_pager, vpc)
        vpc.duration = 700

        view_pager!!.setOnPageChangeListener(object : ViewPager.OnPageChangeListener {
            override fun onPageScrollStateChanged(state: Int) {
            }

            override fun onPageScrolled(position: Int, positionOffset: Float, positionOffsetPixels: Int) {
            }

            override fun onPageSelected(position: Int) {
                println(position)
                tablayout!!.getTabAt(position)!!.select()
            }
        })
    }

    private fun setFragments() {
        fragmens.add(FragmentMarginRanking().initialize(JSONObject().apply {
            put("curr_asset", _curr_asset)
        }))
        fragmens.add(FragmentFeedPrice().initialize(JSONObject().apply {
            put("curr_asset", _curr_asset)
        }))
        fragmens.add(FragmentOrderHistory().initialize(JSONObject().apply {
            put("isSettlementsOrder", true)
        }))
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                _curr_select_index = tab.position
                queryCurrentPage()
                view_pager!!.setCurrentItem(tab.position, true)
            }

            override fun onTabUnselected(tab: TabLayout.Tab) {
                //tab未被选择的时候回调
            }

            override fun onTabReselected(tab: TabLayout.Tab) {
                //tab重新选择的时候回调
            }
        })
    }
}
