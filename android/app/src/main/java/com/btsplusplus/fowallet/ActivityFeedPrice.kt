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
        chainMgr.queryAssetData(_assetList.getJSONObject(pos).getString("id")).then {
            val assetData = it as? JSONObject
            if (assetData == null) {
                mask.dismiss()
                showToast(resources.getString(R.string.kNormalErrorInvalidArgs))
                return@then null
            }

            val promise_map = JSONObject()

            //  1、查询喂价者信息
            val publisher_type:EBitsharesFeedPublisherType
            val flags = assetData.getJSONObject("options").getInt("flags")
            if (flags.and(EBitsharesAssetFlags.ebat_witness_fed_asset.value) != 0) {
                //  由见证人提供喂价
                promise_map.put("kQueryWitness", chainMgr.queryActiveWitnessDataList())
                publisher_type = EBitsharesFeedPublisherType.ebfpt_witness
            } else if (flags.and(EBitsharesAssetFlags.ebat_committee_fed_asset.value) != 0) {
                //  由理事会成员提供喂价
                promise_map.put("kQueryCommittee", chainMgr.queryActiveCommitteeDataList())
                publisher_type = EBitsharesFeedPublisherType.ebfpt_committee
            } else {
                //  由指定账号提供喂价
                publisher_type = EBitsharesFeedPublisherType.ebfpt_custom
            }

            //  2、查询喂价信息
            promise_map.put("kQueryFeedData", conn.async_exec_db("get_objects", jsonArrayfrom(jsonArrayfrom(assetData.getString("bitasset_data_id")))).then {
                return@then (it as JSONArray).getJSONObject(0)
            })

            return@then Promise.map(promise_map).then {
                val datamap = it as JSONObject

                val feed_infos = datamap.getJSONObject("kQueryFeedData")
                val feeds = feed_infos.getJSONArray("feeds")

                val idHash = JSONObject()
                val active_publisher_ids = JSONArray()

                if (publisher_type == EBitsharesFeedPublisherType.ebfpt_witness) {
                    datamap.getJSONArray("kQueryWitness").forEach<JSONObject> {
                        val account_id = it!!.getString("witness_account")
                        active_publisher_ids.put(account_id)
                        idHash.put(account_id, true)
                    }
                } else if (publisher_type == EBitsharesFeedPublisherType.ebfpt_committee) {
                    datamap.getJSONArray("kQueryCommittee").forEach<JSONObject> {
                        val account_id = it!!.getString("committee_member_account")
                        active_publisher_ids.put(account_id)
                        idHash.put(account_id, true)
                    }
                }
                feeds.forEach<JSONArray> {
                    val ary = it!!
                    val account_id = ary.getString(0)
                    if (publisher_type == EBitsharesFeedPublisherType.ebfpt_custom) {
                        active_publisher_ids.put(account_id)
                    }
                    idHash.put(account_id, true)
                }

                return@then chainMgr.queryAllAccountsInfo(idHash.keys().toJSONArray()).then {
                    onQueryFeedInfoResponsed(assetData, feed_infos, feeds, active_publisher_ids, publisher_type, pos)
                    mask.dismiss()
                    return@then null
                }
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    private fun onQueryFeedInfoResponsed(asset: JSONObject, feed_infos: JSONObject, feeds: JSONArray,
                                         active_publisher_ids: JSONArray, publisher_type: EBitsharesFeedPublisherType, pos: Int) {
        assert(pos < fragmens.size)
        (fragmens[pos] as FragmentFeedPrice).onQueryFeedInfoResponsed(asset, feed_infos, feeds, active_publisher_ids, publisher_type)
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
