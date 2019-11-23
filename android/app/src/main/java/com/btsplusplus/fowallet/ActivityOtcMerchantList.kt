package com.btsplusplus.fowallet
import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import android.widget.TextView
import bitshares.toList
import kotlinx.android.synthetic.main.activity_account_info.*
import kotlinx.android.synthetic.main.activity_my_orders.*
import kotlinx.android.synthetic.main.activity_otc_merchant_list.*
import org.json.JSONArray
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityOtcMerchantList : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private lateinit var _asset_name: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_merchant_list)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  Todo 获取参数
//        val args = btspp_args_as_JSONArray()
//        _asset_name  = args[0] as String
        _asset_name = "USD"

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_merchant_list
        view_pager = view_pager_of_merchant_list

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()

        // 根据 资产修改标题
        findViewById<TextView>(R.id.title).text = "CNY 市场"

        // 选择资产
        image_select_asset_from_merchant_list.setOnClickListener {
            onSelectAssetClicked()
        }

        //  返回
        layout_back_from_merchant_list.setOnClickListener { finish() }

    }

    private fun onSelectAssetClicked(){
        val asset_list = JSONArray().apply {
            put("CNY")
            put("USD")
            put("GDEX.CNY")
        }
        ViewSelector.show(this, "请选择要交易的资产", asset_list.toList<String>().toTypedArray()) { index: Int, _: String ->

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
        fragmens.add(FragmentOtcMerchantListBuy().initialize(_asset_name))
        fragmens.add(FragmentOtcMerchantListSell().initialize(_asset_name))
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
