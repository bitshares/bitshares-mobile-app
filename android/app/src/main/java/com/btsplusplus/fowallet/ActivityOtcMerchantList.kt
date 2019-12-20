package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import android.widget.TextView
import bitshares.OtcManager
import bitshares.forin
import bitshares.toList
import kotlinx.android.synthetic.main.activity_otc_merchant_list.*
import org.json.JSONArray
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityOtcMerchantList : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private lateinit var _curr_asset_name: String
    private var _default_ad_type: OtcManager.EOtcAdType = OtcManager.EOtcAdType.eoadt_user_buy
    private var _curr_select_index = 0

    private lateinit var tv_asset_title: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_merchant_list)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _curr_asset_name = args.getString("asset_name")
        _default_ad_type = args.get("ad_type") as OtcManager.EOtcAdType
        _curr_select_index = if (_default_ad_type == OtcManager.EOtcAdType.eoadt_user_buy) {
            0
        } else {
            1
        }

        //  设置 tablelayout 和 view_pager
        tablayout = tablayout_of_merchant_list
        view_pager = view_pager_of_merchant_list

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()

        //  根据 资产修改标题
        tv_asset_title = findViewById<TextView>(R.id.title)
        tv_asset_title.text = "$_curr_asset_name${resources.getString(R.string.kOtcAdTitleBase)}"
        tv_asset_title.setOnClickListener {
            onSelectAssetClicked()
        }

        //  初始化图标颜色
        val iconcolor = resources.getColor(R.color.theme01_textColorNormal)
        img_icon_otc_orders.setColorFilter(iconcolor)
        img_icon_otc_auth.setColorFilter(iconcolor)

        //  事件 - 选择订单列表
        img_icon_otc_orders.setOnClickListener {
            OtcManager.sharedOtcManager().guardUserIdVerified(this, resources.getString(R.string.kOtcAdAskIdVerifyTips01)) { auth_info, _ ->
                goTo(ActivityOtcOrderList::class.java, true, args = JSONObject().apply {
                    put("auth_info", auth_info)
                    put("user_type", OtcManager.EOtcUserType.eout_normal_user)
                })
            }
        }

        //  事件 - 认证和收款方式
        img_icon_otc_auth.setOnClickListener {
            val asset_list = JSONArray().apply {
                put(resources.getString(R.string.kOtcAdUserActionItemAuthInfo))
                put(resources.getString(R.string.kOtcAdUserActionItemReceiveMethod))
            }
            ViewSelector.show(this, "", asset_list.toList<String>().toTypedArray()) { index: Int, _: String ->
                if (index == 0) {
                    //  认证信息
                    OtcManager.sharedOtcManager().guardUserIdVerified(this, null) { auth_info, _ ->
                        goTo(ActivityOtcUserAuthInfos::class.java, true, args = JSONObject().apply {
                            put("auth_info", auth_info)
                        })
                    }
                } else {
                    //  收款方式
                    OtcManager.sharedOtcManager().guardUserIdVerified(this, resources.getString(R.string.kOtcAdAskIdVerifyTips02)) { auth_info, _ ->
                        goTo(ActivityOtcReceiveMethods::class.java, true, args = JSONObject().apply {
                            put("auth_info", auth_info)
                            put("user_type", OtcManager.EOtcUserType.eout_normal_user)
                        })
                    }
                }
            }
        }

        //  返回
        layout_back_from_merchant_list.setOnClickListener { finish() }

        //  查询
        queryCurrentPageAdList()
    }

    private fun queryCurrentPageAdList() {
        fragmens[_curr_select_index].let {
            if (it is FragmentOtcMerchantList) {
                it.queryAdList(_curr_asset_name)
            }
        }
    }

    /**
     * 标题：切换市场
     */
    private fun onSelectAssetClicked() {
        val asset_list = JSONArray()
        for (item in OtcManager.sharedOtcManager().asset_list_digital().forin<JSONObject>()) {
            asset_list.put(item!!.getString("assetSymbol"))
        }
        ViewSelector.show(this, resources.getString(R.string.kOtcAdSwitchAssetTips), asset_list.toList<String>().toTypedArray()) { index: Int, _: String ->
            val asset_name = asset_list.getString(index)
            if (_curr_asset_name != asset_name) {
                _curr_asset_name = asset_name
                //  更新标题
                tv_asset_title.text = "$_curr_asset_name${resources.getString(R.string.kOtcAdTitleBase)}"
                //  查询
                queryCurrentPageAdList()
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
                tablayout!!.getTabAt(position)!!.select()
            }
        })
    }

    private fun setFragments() {
        fragmens.add(FragmentOtcMerchantList().initialize(JSONObject().apply {
            put("ad_type", OtcManager.EOtcAdType.eoadt_user_buy)
            put("user_type", OtcManager.EOtcUserType.eout_normal_user)
        }))
        fragmens.add(FragmentOtcMerchantList().initialize(JSONObject().apply {
            put("ad_type", OtcManager.EOtcAdType.eoadt_user_sell)
            put("user_type", OtcManager.EOtcUserType.eout_normal_user)
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
