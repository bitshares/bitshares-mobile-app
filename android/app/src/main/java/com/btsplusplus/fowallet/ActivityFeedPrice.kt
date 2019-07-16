package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_feed_price.*
import org.json.JSONArray
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityFeedPrice : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null
    private var _assetList = JSONArray()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_feed_price)

        //  初始化参数
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        for (symbol in chainMgr.getDetailFeedPriceSymbolList().forin<String>()) {
            _assetList.put(chainMgr.getAssetBySymbol(symbol!!))
        }

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  返回
        layout_back.setOnClickListener { finish() }

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_detail_feedprice
        view_pager = view_pager_detail_feedprice

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()

        //  开始请求
        queryDetailFeedInfos(0)
    }

    private fun queryDetailFeedInfos(pos: Int) {
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        assert(pos < _assetList.length())
        val asset = _assetList.getJSONObject(pos)

        //  query active witness
        val p0 = conn.async_exec_db("get_global_properties").then {
            val global_data = it as JSONObject
            val active_witnesses = global_data.getJSONArray("active_witnesses")
            return@then conn.async_exec_db("get_witnesses", jsonArrayfrom(active_witnesses))
        }

        //  query bitassets feed data
        val p1 = conn.async_exec_db("get_objects", jsonArrayfrom(jsonArrayfrom(asset.getString("bitasset_data_id")))).then {
            return@then (it as JSONArray).getJSONObject(0)
        }

        Promise.all(p0, p1).then {
            var data_array = it as JSONArray

            val active_witnesses = data_array.getJSONArray(0)
            val infos = data_array.getJSONObject(1)
            val feeds = infos.getJSONArray("feeds")

            val idHash = JSONObject()
            active_witnesses.forEach<JSONObject> {
                idHash.put(it!!.getString("witness_account"), true)
            }
            feeds.forEach<JSONArray> {
                val ary = it!!
                idHash.put(ary.getString(0), true)
            }

            return@then chainMgr.queryAllAccountsInfo(idHash.keys().toJSONArray()).then {
                onQueryFeedInfoResponsed(asset, infos, feeds, active_witnesses, pos)
                mask.dismiss()
                return@then null
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    private fun onQueryFeedInfoResponsed(asset: JSONObject, infos: JSONObject, data_array: JSONArray, active_witnesses: JSONArray, pos: Int) {
        assert(pos < fragmens.size)
        (fragmens[pos] as FragmentFeedPrice).onQueryFeedInfoResponsed(asset, infos, data_array, active_witnesses)
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
            fragmens.add(FragmentFeedPrice())
        }
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                queryDetailFeedInfos(tab.position)
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
