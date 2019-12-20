package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.OtcManager
import kotlinx.android.synthetic.main.activity_otc_mc_home.*
import org.json.JSONObject

class ActivityOtcMcHome : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_home)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val merchant_detail = args.getJSONObject("merchant_detail")

        //  初始化图标颜色
        val iconcolor = resources.getColor(R.color.theme01_textColorNormal)
        img_icon_otc_mc_asset.setColorFilter(iconcolor)
        img_icon_otc_mc_ad.setColorFilter(iconcolor)
        img_icon_otc_mc_order.setColorFilter(iconcolor)
        img_icon_otc_mc_payment.setColorFilter(iconcolor)
        img_icon_otc_mc_receive.setColorFilter(iconcolor)

        val nickname = merchant_detail.getString("nickname")
        tv_mc_first_name_from_otc_mc_home.text = nickname.substring(0, 1)
        tv_mc_first_name_from_otc_mc_home.background = getDrawable(R.drawable.circle_character_view)

        //  TODO:2.9 status
        tv_mc_name_from_otc_mc_home.text = nickname
        tv_auth_text_from_otc_mc_home.text = "已认证"
        tv_date_from_otc_mc_home.text = OtcManager.fmtMerchantTime(merchant_detail.getString("ctime"))

        //  基本信息
        layout_otc_merchant_home_basic.setOnClickListener {
            OtcManager.sharedOtcManager().guardUserIdVerified(this, null) { auth_info, _ ->
                goTo(ActivityOtcUserAuthInfos::class.java, true, args = JSONObject().apply {
                    put("auth_info", auth_info)
                })
            }
        }

        //  商家资产
        layout_asset_list_from_otc_mc_home.setOnClickListener {
            OtcManager.sharedOtcManager().guardUserIdVerified(this, null) { auth_info, _ ->
                goTo(ActivityOtcMcAssetList::class.java, true, args = JSONObject().apply {
                    put("auth_info", auth_info)
                    put("merchant_detail", merchant_detail)
                    put("user_type", OtcManager.EOtcUserType.eout_merchant)
                })
            }
        }

        //  商家广告
        layout_ad_list_from_otc_mc_home.setOnClickListener {
            OtcManager.sharedOtcManager().guardUserIdVerified(this, null) { auth_info, _ ->
                goTo(ActivityOtcMcAdList::class.java, true, args = JSONObject().apply {
                    put("auth_info", auth_info)
                    put("merchant_detail", merchant_detail)
                    put("user_type", OtcManager.EOtcUserType.eout_merchant)
                })
            }
        }

        //  商家订单
        layout_order_list_from_otc_mc_home.setOnClickListener {
            OtcManager.sharedOtcManager().guardUserIdVerified(this, null) { auth_info, _ ->
                goTo(ActivityOtcOrderList::class.java, true, args = JSONObject().apply {
                    put("auth_info", auth_info)
                    put("user_type", OtcManager.EOtcUserType.eout_merchant)
                })
            }
        }

        //  收款方式
        layout_receive_methods_from_otc_mc_home.setOnClickListener {
            OtcManager.sharedOtcManager().guardUserIdVerified(this, null) { auth_info, _ ->
                goTo(ActivityOtcReceiveMethods::class.java, true, args = JSONObject().apply {
                    put("auth_info", auth_info)
                    put("user_type", OtcManager.EOtcUserType.eout_merchant)
                })
            }
        }

        //  付款方式
        layout_payment_methods_from_otc_mc_home.setOnClickListener {
            OtcManager.sharedOtcManager().guardUserIdVerified(this, null) { auth_info, _ ->
                goTo(ActivityOtcMcPaymentMethods::class.java, true, args = JSONObject().apply {
                    put("auth_info", auth_info)
                    put("merchant_detail", merchant_detail)
                })
            }
        }

        //  返回按钮事件
        layout_back_from_otc_mc_home.setOnClickListener { finish() }
    }
}
