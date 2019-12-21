package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import bitshares.*
import kotlinx.android.synthetic.main.activity_otc_order_details.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityOtcOrderDetails : BtsppActivity() {

    private lateinit var _auth_info: JSONObject
    private var _user_type = OtcManager.EOtcUserType.eout_normal_user
    private lateinit var _order_details: JSONObject
    private var _result_promise: Promise? = null

    private lateinit var _statusInfos: JSONObject
    private var _timerID = 0
    private var _currSelectedPaymentMethod: JSONObject? = null          //  买单情况下，当前选中的卖家收款方式。

    override fun onDestroy() {
        //  移除定时器
        AsyncTaskManager.sharedAsyncTaskManager().removeSecondsTimer(_timerID)
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_order_details)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _auth_info = args.getJSONObject("auth_info")
        _user_type = args.get("user_type") as OtcManager.EOtcUserType
        _order_details = args.getJSONObject("order_details")
        _result_promise = args.opt("result_promise") as? Promise

        //  扩展数据
        _statusInfos = OtcManager.auxGenOtcOrderStatusAndActions(this, _order_details, _user_type)
        _changeCurrSelectedPaymentMethod(null)

        //  支付关闭定时器
        _timerID = 0
        val expireDate = _order_details.getInt("expireDate")
        if (expireDate > 0 && !_statusInfos.optBoolean("sell") &&
                _order_details.getInt("status") == OtcManager.EOtcOrderProgressStatus.eoops_new.value) {
            val now_ts = Utils.now_ts()
            val expire_ts = OtcManager.parseTime(_order_details.getString("ctime")) + expireDate.toLong()
            if (now_ts < expire_ts) {
                _timerID = AsyncTaskManager.sharedAsyncTaskManager().scheduledSecondsTimerWithEndTS(expire_ts) { left_ts -> _onPaymentTimerTick(left_ts) }
            }
        }

        //  描绘
        _drawUI_all()

        //  事件 - 返回
        layout_back_from_otc_order_details.setOnClickListener { finish() }

        //  事件 - 电话
        img_icon_phone.setOnClickListener { onPhoneButtonClicked() }

        //  事件 - 各种复制
        btn_copy_curr_payment_realname.setOnClickListener { onCopyButtonClicked(_currSelectedPaymentMethod?.optString("realName", null)) }
        btn_copy_curr_payment_account.setOnClickListener { onCopyButtonClicked(_currSelectedPaymentMethod?.optString("account", null)) }
        btn_copy_order_detail_merchant_name_or_account.setOnClickListener {
            if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                onCopyButtonClicked(_order_details.optString("payRealName", null))
            } else {
                onCopyButtonClicked(_order_details.optString("userAccount", null))
            }
        }
        btn_copy_order_detail_orderid.setOnClickListener { onCopyButtonClicked(_order_details.optString("orderId", null)) }

        //  TODO;2.9
        // 取消订单 支付成功
//        tv_cancel_order_from_otc_order_details.setOnClickListener {
//
//        }
//        tv_payment_success_from_otc_order_details.setOnClickListener {
//

    }

    /**
     *  (private) 待付款定时器
     */
    private fun _onPaymentTimerTick(left_ts: Long) {
        if (left_ts > 0) {
            //  刷新
            val desc = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                String.format(resources.getString(R.string.kOtcOdPaymentTimeLimit), OtcManager.fmtPaymentExpireTime(left_ts))
            } else {
                //   TODO:2.9 lang
                String.format("预计 %s 内收到用户付款。", OtcManager.fmtPaymentExpireTime(left_ts))
            }
            _statusInfos.put("desc", desc)//        }
            //  刷新倒计时描述字符串
            tv_status_desc.text = _statusInfos.getString("desc")
        } else {
            //  TODO:2.9 cancel?
        }
    }

//    /**
//     *  (private) 动态初始化UI需要显示的字段信息按钮等数据。
//     */
//    private fun _initUIData() {
//        //  TODO:2.9 未完成
//        _changeCurrSelectedPaymentMethod(null)
//
//    }

    /**
     *  (private) 刷新UI
     */
    private fun _refreshUI(new_order_detail: JSONObject? = null) {
        if (new_order_detail != null) {
            _order_details = new_order_detail
        }
        _statusInfos = OtcManager.auxGenOtcOrderStatusAndActions(this, _order_details, _user_type)
        _changeCurrSelectedPaymentMethod(null)
        //  刷新UI
        _drawUI_all()
    }

    /**
     *  描绘全部UI
     */
    private fun _drawUI_all() {
        _drawUI_orderStatus()
        _drawUI_orderBasicInfo()
        _drawUI_paymentInfos()
        _drawUI_orderDetails()
        _drawUI_secTips()
        _drawUI_bottomButtons()
    }

    private fun _drawUI_orderStatus() {
        tv_status_main.text = _statusInfos.getString("main")
        tv_status_desc.text = _statusInfos.getString("desc")
        img_icon_phone.setColorFilter(resources.getColor(R.color.theme01_textColorMain))
        //  TODO:2.9 events
//        img_icon_phone
    }

    private fun _drawUI_orderBasicInfo() {
        val fiatSymbol = OtcManager.sharedOtcManager().getFiatCnyInfo().getString("legalCurrencySymbol")
        val assetSymbol = _order_details.getString("assetSymbol")
        //  TODO:2.9 3E+2 格式 未处理
        tv_order_total_value.text = "$fiatSymbol ${_order_details.getString("amount")}"
        tv_unit_price.text = "$fiatSymbol${_order_details.getString("unitPrice")}"
        tv_order_amount.text = "${_order_details.getString("quantity")} $assetSymbol"
    }

    /**
     *  事件 - 切换选择收款方式
     */
    private fun _changeCurrSelectedPaymentMethod(new_select_payment_info: JSONObject? = null) {
        //  有参数则为用户切换，否则为默认初始化。
        _currSelectedPaymentMethod = new_select_payment_info ?: _order_details.optJSONArray("payMethod")?.optJSONObject(0)
    }

    /**
     *  描绘 - 收款方式 - 本人付款提示信息
     */
    private fun __drawUI_payment_same_tips(curr_pm: JSONObject) {
        var realname = _auth_info.optString("realName", null)
        if (realname != null && realname.length >= 2) {
            realname = "*${realname.substring(1)}"
        }
        if (realname != null) {
            realname = "($realname)"
        }
        val pminfos = OtcManager.auxGenPaymentMethodInfos(this, curr_pm.getString("account"), curr_pm.getInt("type"), null)
        val finalString: String
        val colorString: String
        if (realname != null) {
            finalString = String.format(resources.getString(R.string.kOtcOdCellPaymentSameNameTips01), realname, pminfos.optString("name"))
            colorString = realname
        } else {
            finalString = String.format(resources.getString(R.string.kOtcOdCellPaymentSameNameTips02), pminfos.optString("name"))
            colorString = resources.getString(R.string.kOtcOdCellPaymentSameNameTitle)
        }
        //  TODO;2.9 拼接未完成
        tv_pm_sametips_color_string.text = finalString
    }

    /**
     *  描绘 - 收款方式 - 点击切换CELL
     */
    private fun __drawUI_payment_click_switch_cell(curr_pm: JSONObject) {
        //  点击切换收款方式
        val pminfos = OtcManager.auxGenPaymentMethodInfos(this, curr_pm.getString("account"), curr_pm.getInt("type"), curr_pm.optString("bankName"))
        //  图标 + 名字
        img_icon_curr_payment_method.setImageDrawable(resources.getDrawable(pminfos.getInt("icon")))
        tv_curr_payment_method_name.text = pminfos.getString("name")
        //  是否可点击切换
        if (_order_details.getJSONArray("payMethod").length() > 1) {
            layout_curr_payment_method_click_switch.visibility = View.VISIBLE
            img_icon_arrow_curr_payment_method.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
            //  绑定事件
            layout_curr_payment_method_main.setOnClickListener { onSwitchPaymentMethodClicked() }
        } else {
            layout_curr_payment_method_click_switch.visibility = View.INVISIBLE
            layout_curr_payment_method_main.setOnClickListener(null)
        }
    }

    /**
     *  描绘对方收款方式信息（可能不存在）
     */
    private fun _drawUI_paymentInfos() {
        if (_currSelectedPaymentMethod != null) {
            layout_payment_section.visibility = View.VISIBLE
            _currSelectedPaymentMethod?.let { curr_pm ->
                //  本人提示信息
                __drawUI_payment_same_tips(curr_pm)
                //  点击切换CELL
                __drawUI_payment_click_switch_cell(curr_pm)
                //  收款人 TODO:2.9 复制
                tv_curr_payment_realname.text = curr_pm.optString("realName")
                //  收款账号
                tv_curr_payment_account.text = curr_pm.optString("account")
                if (curr_pm.getInt("type") == OtcManager.EOtcPaymentMethodType.eopmt_bankcard.value) {
                    //  开户银行
                    val bankName = curr_pm.opt("bankName") as? String
                    if (bankName != null && bankName.isNotEmpty()) {
                        layout_curr_payment_bankname_cell.visibility = View.VISIBLE
                        layout_curr_payment_bankname_line.visibility = View.VISIBLE
                        tv_curr_payment_bankname.text = bankName
                    } else {
                        layout_curr_payment_bankname_cell.visibility = View.GONE
                        layout_curr_payment_bankname_line.visibility = View.GONE
                    }
                } else {
                    //  二维码 TODO：3.0 暂时不支持
                    layout_curr_payment_bankname_cell.visibility = View.GONE
                    layout_curr_payment_bankname_line.visibility = View.GONE
                }
            }
        } else {
            layout_payment_section.visibility = View.GONE
        }
    }

    /**
     * 描绘订单详情（订单号等)
     */
    private fun _drawUI_orderDetails() {
        //  普通用户：商家姓名 + 商家昵称
        //  商家用户：用户账号 + 空
        if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
            //  商家姓名
            tv_order_detail_merchant_name_or_account_title.text = resources.getString(R.string.kOtcOdCellLabelMcRealName)
            tv_order_detail_merchant_name_or_account_value.text = _order_details.optString("payRealName")
            //  商户昵称
            layout_order_detail_merchant_nickname_line.visibility = View.VISIBLE
            layout_order_detail_merchant_nickname_cell.visibility = View.VISIBLE
            tv_order_detail_merchant_nickname_value.text = _order_details.optString("merchantsNickname")
        } else {
            tv_order_detail_merchant_name_or_account_title.text = "用户账号"//TODO:2.9 lang
            tv_order_detail_merchant_name_or_account_value.text = _order_details.optString("userAccount")

            layout_order_detail_merchant_nickname_line.visibility = View.GONE
            layout_order_detail_merchant_nickname_cell.visibility = View.GONE
        }

        //  订单编号
        tv_order_detail_orderid_value.text = _order_details.optString("orderId")

        //  订单日期
        tv_order_detail_time_value.text = OtcManager.fmtOrderDetailTime(_order_details.getString("ctime"))

        //  收款方式 or 付款方式
        val payAccount = _order_details.opt("payAccount") as? String
        if (payAccount != null && payAccount.isNotEmpty()) {
            layout_order_detail_payment_or_receive_item_cell.visibility = View.VISIBLE
            layout_order_detail_payment_or_receive_item_line.visibility = View.VISIBLE

            val pminfos = OtcManager.auxGenPaymentMethodInfos(this, payAccount, _order_details.optInt("payChannel"), null)
            tv_order_detail_payment_or_receive_item_title.text = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                if (_statusInfos.getBoolean("sell")) {
                    resources.getString(R.string.kOtcAdCellLabelTitleReceiveMethod)
                } else {
                    resources.getString(R.string.kOtcAdCellLabelTitlePaymentMethod)
                }
            } else {
                if (_statusInfos.getBoolean("sell")) {
                    resources.getString(R.string.kOtcAdCellLabelTitlePaymentMethod)
                } else {
                    resources.getString(R.string.kOtcAdCellLabelTitleReceiveMethod)
                }
            }
            //  TODO:2.9 pminfos.getInt("icon") + pminfos.getString("name_with_short_account") 未完成
        } else {
            layout_order_detail_payment_or_receive_item_cell.visibility = View.GONE
            layout_order_detail_payment_or_receive_item_line.visibility = View.GONE
        }
    }

    /**
     * 描绘订单安全转账提示
     */
    private fun _drawUI_secTips() {
        if (_statusInfos.getBoolean("show_remark")) {
            tv_order_payment_sectips.visibility = View.VISIBLE

            val tips_array = mutableListOf<String>()
            val remark = _order_details.opt("remark") as? String
            if (remark != null && remark.isNotEmpty()) {
                tips_array.add("${resources.getString(R.string.kOtcOdPaymentTipsMcRemarkPrefix)}$remark")
            }
            tips_array.add(resources.getString(R.string.kOtcOdPaymentTipsSystemMsg))
            tv_order_payment_sectips.text = tips_array.joinToString("\n\n")
        } else {
            tv_order_payment_sectips.visibility = View.GONE
        }
    }

    private fun _drawUI_bottomButtons() {
        val actions = _statusInfos.optJSONArray("actions")
        if (actions != null && actions.length() > 0) {
            assert(actions.length() <= 2)
            layout_order_bottom_buttons.visibility = View.VISIBLE
            //  动态设置布局参数
            btn_order_button01.setOnClickListener { onButtomButtonClicked(it) }
            if (actions.length() == 2) {
                btn_order_button02.visibility = View.VISIBLE
                //  如果有2个按钮则取消第一个按钮的右margin
                val layoutParams = btn_order_button01.layoutParams as LinearLayout.LayoutParams
                layoutParams.setMargins(8.dp, 8.dp, 0, 8.dp)
                btn_order_button01.layoutParams = layoutParams
                btn_order_button02.setOnClickListener { onButtomButtonClicked(it) }
            } else {
                btn_order_button02.visibility = View.GONE
                val layoutParams = btn_order_button01.layoutParams as LinearLayout.LayoutParams
                layoutParams.setMargins(8.dp, 8.dp, 8.dp, 8.dp)
                btn_order_button01.layoutParams = layoutParams
                btn_order_button02.setOnClickListener(null)
            }
            var idx = 0
            for (item in actions.forin<JSONObject>()) {
                val curr_button = if (idx == 0) btn_order_button01 else btn_order_button02
                //  设置按钮文字
                val btnType = item!!.get("type") as OtcManager.EOtcOrderOperationType
                when (btnType) {
                    //  卖单
                    OtcManager.EOtcOrderOperationType.eooot_transfer -> {
                        curr_button.text = resources.getString(R.string.kOtcOdBtnTransfer)
                    }
                    OtcManager.EOtcOrderOperationType.eooot_contact_customer_service -> {
                        curr_button.text = resources.getString(R.string.kOtcOdBtnCustomerService)
                    }
                    OtcManager.EOtcOrderOperationType.eooot_confirm_received_money -> {
                        curr_button.text = "${resources.getString(R.string.kOtcOdBtnConfirmReceivedMoney)} ${_order_details.optString("assetSymbol")}"
                    }
                    //  买单
                    OtcManager.EOtcOrderOperationType.eooot_cancel_order -> {
                        curr_button.text = resources.getString(R.string.kOtcOdBtnCancelOrder)
                    }
                    OtcManager.EOtcOrderOperationType.eooot_confirm_paid -> {
                        curr_button.text = resources.getString(R.string.kOtcOdBtnConfirmPaid)
                    }
                    OtcManager.EOtcOrderOperationType.eooot_confirm_received_refunded -> {
                        curr_button.text = resources.getString(R.string.kOtcOdBtnConfirmReceivedRefunded)
                    }
                    //  商家 TODO:2.9 lang
                    OtcManager.EOtcOrderOperationType.eooot_mc_cancel_sell_order, OtcManager.EOtcOrderOperationType.eooot_mc_cancel_buy_order -> {
                        curr_button.text = "无法接单"
                    }
                    OtcManager.EOtcOrderOperationType.eooot_mc_confirm_paid -> {
                        curr_button.text = resources.getString(R.string.kOtcOdBtnConfirmPaid)
                    }
                    OtcManager.EOtcOrderOperationType.eooot_mc_confirm_received_money -> {
                        curr_button.text = "${resources.getString(R.string.kOtcOdBtnConfirmReceivedMoney)} ${_order_details.optString("assetSymbol")}"
                    }
                }
                //  设置颜色
                curr_button.setBackgroundColor(resources.getColor(item.getInt("color")))
                //  设置TAG
                curr_button.tag = btnType
                ++idx
            }
        } else {
            btn_order_button01.setOnClickListener(null)
            btn_order_button02.setOnClickListener(null)
            layout_order_bottom_buttons.visibility = View.GONE
        }
    }

    /**
     *  事件 - 点击切换收款方式
     */
    private fun onSwitchPaymentMethodClicked() {
        val payMethod = _order_details.optJSONArray("payMethod")
        if (payMethod != null && payMethod.length() > 0) {
            val nameList = JSONArray()
            for (pm in payMethod.forin<JSONObject>()) {
                val pminfos = OtcManager.auxGenPaymentMethodInfos(this, pm!!.getString("account"), pm.getInt("type"), pm.optString("bankName"))
                nameList.put(pminfos.getString("name_with_short_account"))
            }
            ViewSelector.show(this, resources.getString(R.string.kOtcAdCellSelectMcReceiveMethodTitle), nameList.toList<String>().toTypedArray()) { index: Int, _: String ->
                val selectedPaymentMethod = payMethod.getJSONObject(index)
                val new_id = selectedPaymentMethod.getString("id")
                val old_id = _currSelectedPaymentMethod!!.getString("id")
                if (new_id != old_id) {
                    // 更新商家收款方式相关字段
                    _changeCurrSelectedPaymentMethod(selectedPaymentMethod)
                    _drawUI_paymentInfos()
                }
            }
        }
    }

    /**
     *  (public) 用户点击电话按钮联系对方
     */
    private fun onPhoneButtonClicked() {
        val phone = _order_details.opt("phone") as? String
        if (phone != null && phone.isNotEmpty()) {
            showToast("call: $phone")
            //  TODO:2.9 !!! 重要 打电话 未完成
        }
    }

    /**
     * (private) 复制按钮点击
     */
    private fun onCopyButtonClicked(value: String?) {
        if (value != null && value.isNotEmpty()) {
            if (Utils.copyToClipboard(this, value)) {
                showToast(resources.getString(R.string.kOtcOdCopiedTips))
            }
        }
    }

    /**
     *  底部按钮点击事件
     */
    private fun onButtomButtonClicked(btn: View) {
        val btnType = btn.tag as? OtcManager.EOtcOrderOperationType
        if (btnType != null) {
            showToast("clicked: ${btnType.value}")
            when (btnType) {
                //  卖单
                OtcManager.EOtcOrderOperationType.eooot_transfer -> {
//                    curr_button.text = resources.getString(R.string.kOtcOdBtnTransfer)
                }
                OtcManager.EOtcOrderOperationType.eooot_contact_customer_service -> {
//                    curr_button.text = resources.getString(R.string.kOtcOdBtnCustomerService)
                }
                OtcManager.EOtcOrderOperationType.eooot_confirm_received_money -> {
//                    curr_button.text = "${resources.getString(R.string.kOtcOdBtnConfirmReceivedMoney)} ${_order_details.optString("assetSymbol")}"
                }
                //  买单
                OtcManager.EOtcOrderOperationType.eooot_cancel_order -> {
//                    curr_button.text = resources.getString(R.string.kOtcOdBtnCancelOrder)
                }
                OtcManager.EOtcOrderOperationType.eooot_confirm_paid -> {
//                    curr_button.text = resources.getString(R.string.kOtcOdBtnConfirmPaid)
                }
                OtcManager.EOtcOrderOperationType.eooot_confirm_received_refunded -> {
//                    curr_button.text = resources.getString(R.string.kOtcOdBtnConfirmReceivedRefunded)
                }
                //  商家 TODO:2.9 lang
                OtcManager.EOtcOrderOperationType.eooot_mc_cancel_sell_order, OtcManager.EOtcOrderOperationType.eooot_mc_cancel_buy_order -> {
//                    curr_button.text = "无法接单"
                }
                OtcManager.EOtcOrderOperationType.eooot_mc_confirm_paid -> {
//                    curr_button.text = resources.getString(R.string.kOtcOdBtnConfirmPaid)
                }
                OtcManager.EOtcOrderOperationType.eooot_mc_confirm_received_money -> {
//                    curr_button.text = "${resources.getString(R.string.kOtcOdBtnConfirmReceivedMoney)} ${_order_details.optString("assetSymbol")}"
                }
            }
        }
    }

}
