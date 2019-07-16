package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_margin_ranking.*
import org.json.JSONArray
import java.lang.reflect.Field

class ActivityMarginRanking : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null
    private var _assetList = JSONArray()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_margin_ranking)

        //  初始化参数
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        for (symbol in chainMgr.getCallOrderRankingSymbolList().forin<String>()) {
            _assetList.put(chainMgr.getAssetBySymbol(symbol!!))
        }

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

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
        queryCallOrderData(0)
    }

    private fun queryCallOrderData(pos: Int) {
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        assert(pos < _assetList.length())
        val asset = _assetList.getJSONObject(pos)
        val p1 = conn.async_exec_db("get_call_orders", jsonArrayfrom(asset.getString("id"), 50))
        val p2 = conn.async_exec_db("get_objects", jsonArrayfrom(jsonArrayfrom(asset.getString("bitasset_data_id")))).then {
            return@then (it as JSONArray).getJSONObject(0)
        }
        Promise.all(p1, p2).then { it ->
            val data_array = it as JSONArray
            val borrower_list = JSONArray()
            for (order in data_array.getJSONArray(0)) {
                borrower_list.put(order!!.getString("borrower"))
            }
            return@then chainMgr.queryAllAccountsInfo(borrower_list).then {
                onQueryCallOrderDataResponsed(data_array, pos)
                mask.dismiss()
                return@then null
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    private fun onQueryCallOrderDataResponsed(data_array: JSONArray, pos: Int) {
        assert(pos < fragmens.size)
        runOnMainUI {
            (fragmens[pos] as FragmentMarginRanking).onQueryCallOrderDataResponsed(data_array)
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
        for (asset in _assetList) {
            fragmens.add(FragmentMarginRanking())
        }
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                queryCallOrderData(tab.position)
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
