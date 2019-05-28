package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import com.btsplusplus.fowallet.kline.TradingPair
import kotlinx.android.synthetic.main.activity_my_orders.*
import org.json.JSONArray
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityMyOrders : BtsppActivity() {


    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private var _full_account_data: JSONObject? = null
    private var _tradeHistory: JSONArray? = null
    private var _tradingPair: TradingPair? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_my_orders)

        //  获取参数
        var args = btspp_args_as_JSONArray()
        _full_account_data = args[0] as JSONObject
        _tradeHistory = args[1] as JSONArray
        _tradingPair = args[2] as? TradingPair

        layout_back_from_my_orders.setOnClickListener { finish() }

        setFullScreen()

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_my_orders
        view_pager = view_pager_of_my_orders

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()
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
        fragmens.add(FragmentOrderCurrent().initialize(_full_account_data!!))
        fragmens.add(FragmentOrderHistory().initialize(_tradeHistory!!))
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
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
