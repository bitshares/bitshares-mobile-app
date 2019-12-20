package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import bitshares.OtcManager
import kotlinx.android.synthetic.main.activity_otc_order_list.*
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityOtcOrderList : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private lateinit var _auth_info: JSONObject
    private var _user_type = OtcManager.EOtcUserType.eout_normal_user
    private var _curr_select_index = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_order_list)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _auth_info = args.getJSONObject("auth_info")
        _user_type = args.get("user_type") as OtcManager.EOtcUserType
        _curr_select_index = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
            0
        } else {
            1
        }

        //  UI - 初始化page bar
        val pages = findViewById<android.support.design.widget.TabLayout>(R.id.tablayout_of_otc_order_list)
        if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
            pages.removeTabAt(3)
            pages.getTabAt(0)!!.text = resources.getString(R.string.kOtcOrderPageTitlePending)
            pages.getTabAt(1)!!.text = resources.getString(R.string.kOtcOrderPageTitleCompleted)
            pages.getTabAt(2)!!.text = resources.getString(R.string.kOtcOrderPageTitleCancelled)
        } else {
            pages.getTabAt(0)!!.text = resources.getString(R.string.kOtcOrderPageTitleAll)
            pages.getTabAt(1)!!.text = resources.getString(R.string.kOtcOrderPageTitleWaitProcessing)
            pages.getTabAt(2)!!.text = resources.getString(R.string.kOtcOrderPageTitlePending)
            pages.getTabAt(3)!!.text = resources.getString(R.string.kOtcOrderPageTitleCompleted)
        }

        //  返回
        layout_back_from_otc_merchant_order_list.setOnClickListener { finish() }

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_otc_order_list
        view_pager = view_pager_of_otc_order_list

        //  添加 fargments
        setFragments()

        //  设置 viewPager 并配置滚动速度
        setViewPager()

        //  监听 tab 并设置选中 item
        setTabListener()

        //  查询
        queryCurrentPageOrders()
    }

    private fun queryCurrentPageOrders() {
        fragmens[_curr_select_index].let {
            if (it is FragmentOtcOrderList) {
                it.queryCurrentPageOrders()
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

        //  默认选中
        tablayout!!.getTabAt(_curr_select_index)!!.select()
        view_pager!!.currentItem = _curr_select_index
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
        if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
            fragmens.add(FragmentOtcOrderList().initialize(JSONObject().apply {
                put("auth_info", _auth_info)
                put("user_type", _user_type)
                put("order_status", OtcManager.EOtcOrderStatus.eoos_pending)
            }))
            fragmens.add(FragmentOtcOrderList().initialize(JSONObject().apply {
                put("auth_info", _auth_info)
                put("user_type", _user_type)
                put("order_status", OtcManager.EOtcOrderStatus.eoos_completed)
            }))
            fragmens.add(FragmentOtcOrderList().initialize(JSONObject().apply {
                put("auth_info", _auth_info)
                put("user_type", _user_type)
                put("order_status", OtcManager.EOtcOrderStatus.eoos_cancelled)
            }))
        } else {
            fragmens.add(FragmentOtcOrderList().initialize(JSONObject().apply {
                put("auth_info", _auth_info)
                put("user_type", _user_type)
                put("order_status", OtcManager.EOtcOrderStatus.eoos_all)
            }))
            fragmens.add(FragmentOtcOrderList().initialize(JSONObject().apply {
                put("auth_info", _auth_info)
                put("user_type", _user_type)
                put("order_status", OtcManager.EOtcOrderStatus.eoos_mc_wait_process)
            }))
            fragmens.add(FragmentOtcOrderList().initialize(JSONObject().apply {
                put("auth_info", _auth_info)
                put("user_type", _user_type)
                put("order_status", OtcManager.EOtcOrderStatus.eoos_mc_pending)
            }))
            fragmens.add(FragmentOtcOrderList().initialize(JSONObject().apply {
                put("auth_info", _auth_info)
                put("user_type", _user_type)
                put("order_status", OtcManager.EOtcOrderStatus.eoos_mc_done)
            }))
        }
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                _curr_select_index = tab.position
                queryCurrentPageOrders()
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
