package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import bitshares.toList
import kotlinx.android.synthetic.main.activity_otc_order_details.*
import org.json.JSONArray

class ActivityOtcOrderDetails : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_order_details)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  返回
        layout_back_from_otc_order_details.setOnClickListener { finish() }

        iv_check_from_otc_order_details.setColorFilter(resources.getColor(R.color.theme01_textColorMain))
        iv_toggle_payment_method_right_arrow_from_otc_order_details.setColorFilter(resources.getColor(R.color.theme01_textColorGray))

        // 付款信息
        tv_payment_tips_from_otc_order_details.text = "请在12:33内付款给卖家"
        tv_pay_amount_from_otc_order_details.text = "¥ 28.84"
        tv_pay_price_from_otc_order_details.text = "¥ 7.21"
        tv_buy_quantity_from_otc_order_details.text = "4 USD"
        tv_buy_bankcard_realname_from_otc_order_details.text = "(*洋明)"

        // 付款方式 姓名 和 图标
        iv_payment_method_icon_from_otc_order_details.setImageDrawable(resources.getDrawable(R.drawable.icon_pm_bankcard))
        tv_payment_method_name_from_otc_order_details.text = "中国银行"

        // 收款人 姓名 和 图标
        tv_receiver_name_from_otc_order_details.text = "江博"
        iv_receiver_method_icon_from_otc_order_details.setImageDrawable(resources.getDrawable(R.drawable.icon_pm_bankcard))

        // 收款人 账号 和 图标
        tv_receiver_account_from_otc_order_details.text = "1919 2554 2565 2321 292"
        iv_account_receiver_method_icon_from_otc_order_details.setImageDrawable(resources.getDrawable(R.drawable.icon_pm_bankcard))

        // 开户银行
        tv_receiver_method_type_name_from_otc_order_details.text = "开户银行"
        tv_receiver_bankname_from_otc_order_details.text = "中国银行"

        // 商家姓名
        tv_merchant_name_from_otc_order_details.text = "江博"
        iv_merchant_name_icon_from_otc_order_details.setImageDrawable(resources.getDrawable(R.drawable.icon_pm_bankcard))

        // 商家昵称
        tv_merchant_nickname_from_otc_order_details.text = "吉祥承兑"

        // 订单编号
        tv_order_no_from_otc_order_details.text = "3121323j12klj312j3kl1jsfkljsfkljlkjf2j1l2kj3llk"
        iv_order_no_icon_from_otc_order_details.setImageDrawable(resources.getDrawable(R.drawable.icon_pm_bankcard))

        // 下单日期
        tv_order_create_time_from_otc_order_details.text = "2019-12-12 20:20:20"
        tv_tips_from_otc_order_details.text = "商家:提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示。\n\n 系统: 提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示提示"

        // 切换方式
        ly_toggle_payment_method_from_otc_order_details.setOnClickListener{
            toggle_payment_method_onClicked()
        }

        // 取消订单 支付成功
        tv_cancel_order_from_otc_order_details.setOnClickListener {

        }
        tv_payment_success_from_otc_order_details.setOnClickListener{

        }
    }

    private fun toggle_payment_method_onClicked(){
        val asset_list = JSONArray().apply {
            put("支付宝(18888882)")
            put("微信支付(oyoyod)")
            put("中国银行(839218398)")
            put("银行卡(1919 1991 1919 1999 222)")
        }
        ViewSelector.show(this, "请选择卖家收获方式", asset_list.toList<String>().toTypedArray()) { index: Int, _: String ->

        }
    }
}
