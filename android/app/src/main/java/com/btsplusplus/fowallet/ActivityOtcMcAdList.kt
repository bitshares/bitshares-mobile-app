package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import bitshares.OtcManager
import bitshares.Promise
import kotlinx.android.synthetic.main.activity_otc_mc_ad_list.*
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityOtcMcAdList : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private lateinit var _auth_info: JSONObject
    private lateinit var _merchant_detail: JSONObject
    private var _user_type = OtcManager.EOtcUserType.eout_merchant

    private var _curr_select_index = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_ad_list)
        // 设置全屏
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _auth_info = args.getJSONObject("auth_info")
        _merchant_detail = args.getJSONObject("merchant_detail")
        _user_type = args.get("user_type") as OtcManager.EOtcUserType

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_otc_ad_list
        view_pager = view_pager_of_otc_ad_list

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()

        //  事件
        button_add_ad_from_otc_mc_ad_list.setOnClickListener { onAddNewAdClicked() }
        layout_back_from_otc_mc_ad_list.setOnClickListener { finish() }

        //  查询
        queryCurrentPageAdList()
    }

    private fun queryCurrentPageAdList() {
        fragmens[_curr_select_index].let {
            if (it is FragmentOtcMerchantList) {
                it.queryAdList("")
            }
        }
    }

    private fun onAddNewAdClicked() {
        val result_promise = Promise()
        goTo(ActivityOtcMcAdUpdate::class.java, true, args = JSONObject().apply {
            put("auth_info", _auth_info)
            put("merchant_detail", _merchant_detail)
            put("user_type", _user_type)
            put("ad_info", null)
            put("result_promise", result_promise)
        })
        result_promise.then { dirty ->
            //  刷新UI
            if (dirty != null && dirty as Boolean) {
                queryCurrentPageAdList()
            }
        }
    }

    private fun setViewPager() {
        view_pager!!.adapter = ViewPagerAdapter(super.getSupportFragmentManager(), fragmens)
        val f: Field = ViewPager::class.java.getDeclaredField("mScroller")
        f.isAccessible = true
        val vpc: ViewPagerScroller = ViewPagerScroller(view_pager!!.context, OvershootInterpolator(0.6f))
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
        fragmens.add(FragmentOtcMerchantList().initialize(JSONObject().apply {
            put("auth_info", _auth_info)
            put("merchant_detail", _merchant_detail)
            put("user_type", _user_type)
            put("ad_status", OtcManager.EOtcAdStatus.eoads_online)
        }))
        fragmens.add(FragmentOtcMerchantList().initialize(JSONObject().apply {
            put("auth_info", _auth_info)
            put("merchant_detail", _merchant_detail)
            put("user_type", _user_type)
            put("ad_status", OtcManager.EOtcAdStatus.eoads_offline)
        }))
        fragmens.add(FragmentOtcMerchantList().initialize(JSONObject().apply {
            put("auth_info", _auth_info)
            put("merchant_detail", _merchant_detail)
            put("user_type", _user_type)
            put("ad_status", OtcManager.EOtcAdStatus.eoads_deleted)
        }))
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                _curr_select_index = tab.position
                queryCurrentPageAdList()
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
