package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.OtcManager
import bitshares.isTrue
import bitshares.toList
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
                //  TODO:3.0 激活代码临时放在这里
                if (merchant_detail.getInt("status") == OtcManager.EOtcMcStatus.eoms_not_active.value ||
                        merchant_detail.getInt("level") <= 0) {
                    processMerchantActive(auth_info, merchant_detail)
                } else {
                    goTo(ActivityOtcMcAdList::class.java, true, args = JSONObject().apply {
                        put("auth_info", auth_info)
                        put("merchant_detail", merchant_detail)
                        put("user_type", OtcManager.EOtcUserType.eout_merchant)
                    })
                }
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

    private fun processMerchantActive(auto_info: JSONObject, merchant_detail: JSONObject) {
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
        //  查询商家制度
        val otc = OtcManager.sharedOtcManager()
        otc.merchantPolicy(otc.getCurrentBtsAccount()).then {
            mask.dismiss()
            val responsed = it as? JSONObject
            val data = responsed?.optJSONObject("data")
            val merchantPolicyList = data?.optJSONArray("merchantPolicyList")
            if (merchantPolicyList == null || merchantPolicyList.length() <= 0) {
                showToast(resources.getString(R.string.kOtcMgrMcActiveNoPolicy))
                return@then null
            }

            val assetSymbol = data.getString("mortgageAssetSymbol")

            //  按照保证金升序排列
            val sorted_list = merchantPolicyList.toList<JSONObject>().sortedBy { it.getInt("mortgage") }

            //  选择第一个保证金最低的商家制度
            val firstMerchantPolicy = sorted_list[0]

            //  提示信息
            val msg = String.format(resources.getString(R.string.kOtcMgrMcActiveAskMessage), firstMerchantPolicy.getString("mortgage"), assetSymbol)

            //  激活提示
            UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), msg, btn_ok = resources.getString(R.string.kOtcMgrMcActiveAskBtnActiveNow)).then {
                if (it != null && it as Boolean) {
                    guardWalletUnlocked(true) { unlocked ->
                        if (unlocked) {
                            val mask2 = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
                            otc.merchantActive(otc.getCurrentBtsAccount()).then {
                                mask2.dismiss()
                                val responsed2 = it as? JSONObject
                                val succ = responsed2?.isTrue("data") ?: false
                                if (succ) {
                                    showToast(resources.getString(R.string.kOtcMgrMcActiveTipsOK))
                                    //  本地设置已激活标记
                                    merchant_detail.put("status", OtcManager.EOtcMcStatus.eoms_activated.value)
                                    //  TODO:2.9 商家等级暂时设置为 1
                                    merchant_detail.put("level", 1)
                                } else {
                                    //  激活失败
                                    showToast(resources.getString(R.string.kOtcMgrMcActiveFailedTipMessage))
                                }
                                //  TODO:3.0 如果界面有区别显示则需要刷新
                                return@then null
                            }.catch { err ->
                                mask2.dismiss()
                                otc.showOtcError(this, err)
                            }
                        }
                    }
                }
                return@then null
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }
    }

}
