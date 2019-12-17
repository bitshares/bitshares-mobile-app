package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import kotlinx.android.synthetic.main.activity_otc_mc_home.*
import org.json.JSONObject

class ActivityOtcMcHome : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_home)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  初始化图标颜色
        val iconcolor = resources.getColor(R.color.theme01_textColorNormal)
        img_icon_otc_mc_asset.setColorFilter(iconcolor)
        img_icon_otc_mc_ad.setColorFilter(iconcolor)
        img_icon_otc_mc_order.setColorFilter(iconcolor)
        img_icon_otc_mc_payment.setColorFilter(iconcolor)
        img_icon_otc_mc_receive.setColorFilter(iconcolor)

        tv_mc_first_name_from_otc_mc_home.text = "素"
        tv_mc_first_name_from_otc_mc_home.background = getDrawable(R.drawable.circle_character_view)

        tv_mc_name_from_otc_mc_home.text = "素素承兑"
        tv_auth_text_from_otc_mc_home.text = "已认证"
        tv_date_from_otc_mc_home.text = "2019-12-12"

        // 商家资产
        layout_asset_list_from_otc_mc_home.setOnClickListener {
            goTo(ActivityOtcMcAssetList::class.java,true)
        }

        // 商家广告
        layout_ad_list_from_otc_mc_home.setOnClickListener {
            goTo(ActivityOtcMcAdList::class.java,true)
        }

        // 商家订单
        layout_order_list_from_otc_mc_home.setOnClickListener {
            goTo(ActivityOtcOrderList::class.java,true)
        }

        // 收款方式
        layout_receive_methods_from_otc_mc_home.setOnClickListener {
            val _args = JSONObject().apply {
                put("type", "receive")
            }
            goTo(ActivityOtcMcPaymentMethods::class.java,true, args = _args)
        }

        // 付款方式
        layout_payment_methods_from_otc_mc_home.setOnClickListener {
            val _args = JSONObject().apply {
                put("type", "payment")
            }
            goTo(ActivityOtcMcPaymentMethods::class.java,true, args = _args)
        }



        // 返回按钮事件
        layout_back_from_otc_mc_home.setOnClickListener { finish() }
    }
}
