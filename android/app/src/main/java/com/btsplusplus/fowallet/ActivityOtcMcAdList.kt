package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import kotlinx.android.synthetic.main.activity_otc_mc_ad_list.*
import kotlinx.android.synthetic.main.activity_otc_merchant_list.*
import org.json.JSONArray
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityOtcMcAdList : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private lateinit var _asset_name: String
    private lateinit var _data: JSONArray

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_ad_list)
        // 设置全屏
        setFullScreen()

        _asset_name = "CNY"

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_otc_ad_list
        view_pager = view_pager_of_otc_ad_list

        getData()

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()

        button_add_ad_from_otc_mc_ad_list.setOnClickListener {
            goTo(ActivityOtcMcAdUpdate::class.java,true)
        }

        layout_back_from_otc_mc_ad_list.setOnClickListener { finish() }
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

    private fun getData() {
        _data = JSONArray().apply {
            for (i in 0 until 10){
                put(JSONObject().apply {
                    put("mmerchant_name","吉祥承兑")

                    put("trade_count",1500)
                    put("legal_asset_symbol","¥")
                    put("limit_min","30")
                    put("limit_max","1250")
                    put("price","7.21")
                    put("ad_type", 1 + (i % 2))
                    put("payment_methods", JSONArray().apply {
                        put("alipay")
                        put("bankcard")
                    })
                })
            }
        }
    }

    private fun setFragments() {

        // REMARK : 这里公用商家列表的 Fragment, 需要分类

        val _args1 = JSONObject().apply {
            put("entry","otc_ad_list")
            put("data",_data)
            put("asset_name",_asset_name)
        }

        val _args2 = JSONObject().apply {
            put("entry","otc_ad_list")
            put("data",_data)
            put("asset_name",_asset_name)
        }

        val _args3 = JSONObject().apply {
            put("entry","otc_ad_list")
            put("data",_data)
            put("asset_name",_asset_name)
        }

        fragmens.add(FragmentOtcMerchantList().initialize(_args1))
        fragmens.add(FragmentOtcMerchantList().initialize(_args2))
        fragmens.add(FragmentOtcMerchantList().initialize(_args3))
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
