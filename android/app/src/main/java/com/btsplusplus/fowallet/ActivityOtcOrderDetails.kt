package com.btsplusplus.fowallet

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_otc_order_details.*
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max

class ActivityOtcOrderDetails : BtsppActivity() {

    private lateinit var _auth_info: JSONObject
    private var _user_type = OtcManager.EOtcUserType.eout_normal_user
    private lateinit var _order_details: JSONObject
    private var _result_promise: Promise? = null

    private lateinit var _statusInfos: JSONObject
    private var _timerID = 0
    private var _currSelectedPaymentMethod: JSONObject? = null          //  买单情况下，当前选中的卖家收款方式。

    private var _orderStatusDirty = false                               //  订单状态是否更新过了

    override fun onDestroy() {
        _stopPaymentTimer()
        super.onDestroy()
    }

    private fun _stopPaymentTimer() {
        if (_timerID != 0) {
            AsyncTaskManager.sharedAsyncTaskManager().removeSecondsTimer(_timerID)
            _timerID = 0
        }
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
        layout_back_from_otc_order_details.setOnClickListener {
            _result_promise?.resolve(_orderStatusDirty)
            _result_promise = null
            finish()
        }

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
                String.format(resources.getString(R.string.kOtcOdMcPaymentTimeLimit), OtcManager.fmtPaymentExpireTime(left_ts))
            }
            _statusInfos.put("desc", desc)//        }
            //  刷新倒计时描述字符串
            tv_status_desc.text = _statusInfos.getString("desc")
        } else {
            //  TODO:2.9 cancel? 未完成 定时器到了应该是直接刷新页面？
        }
    }

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
        val headerString: String
        val middleString: String
        val tailerString = String.format(resources.getString(R.string.kOtcOdCellPaymentSameNameTipsAndroidTailer), pminfos.optString("name"))
        if (realname != null) {
            headerString = resources.getString(R.string.kOtcOdCellPaymentSameNameTipsAndroidHeader01)
            middleString = realname
        } else {
            headerString = resources.getString(R.string.kOtcOdCellPaymentSameNameTipsAndroidHeader02)
            middleString = resources.getString(R.string.kOtcOdCellPaymentSameNameTitle)
        }
        tv_pm_sametips_prev_string.text = headerString
        tv_pm_sametips_color_string.text = middleString
        tv_pm_sametips_after_string.text = tailerString
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
                //  收款人
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
            tv_order_detail_merchant_name_or_account_title.text = resources.getString(R.string.kOtcOdCellLabelUserAccount)
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

            //  标题
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

            //  图标 + 值
            img_order_detail_payment_or_receive_item_icon.setImageDrawable(resources.getDrawable(pminfos.getInt("icon")))
            tv_order_detail_payment_or_receive_item_value.text = pminfos.getString("name_with_short_account")
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
                    //  商家
                    OtcManager.EOtcOrderOperationType.eooot_mc_cancel_sell_order, OtcManager.EOtcOrderOperationType.eooot_mc_cancel_buy_order -> {
                        curr_button.text = resources.getString(R.string.kOtcOdBtnMcCancelOrder)
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
            //  TODO:2.9 lang
            this.guardPermissions(Manifest.permission.CALL_PHONE).then {
                when (it as Int) {
                    EBtsppPermissionResult.GRANTED.value -> {
                        val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$phone"))
                        startActivity(intent)
                    }
                    else -> {
                        if (Utils.copyToClipboard(this, phone)) {
                            showToast("无权限，您可以手动拨打电话：$phone，号码已复制。")
                        } else {
                            showToast("无权限，您可以手动拨打电话：$phone")
                        }
                    }
                }
                return@then null
            }
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
            when (btnType) {
                //  卖单
                OtcManager.EOtcOrderOperationType.eooot_transfer -> {
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kOtcOdUserAskTransferTitle), resources.getString(R.string.kOtcOdUserAskTransferMessage)).then {
                        if (it != null && it as Boolean) {
                            _execTransferCore()
                        }
                    }
                }
                OtcManager.EOtcOrderOperationType.eooot_contact_customer_service -> {
                    OtcManager.sharedOtcManager().gotoSupportPage(this)
                }
                OtcManager.EOtcOrderOperationType.eooot_confirm_received_money -> {
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kOtcOdUserConfirmReceiveMoneyTitle), resources.getString(R.string.kOtcOdUserConfirmReceiveMoneyMessage)).then {
                        if (it != null && it as Boolean) {
                            guardWalletUnlocked(true) { unlocked ->
                                if (unlocked) {
                                    _execUpdateOrderCore(_order_details.getString("payAccount"),
                                            _order_details.get("payChannel"),
                                            OtcManager.EOtcOrderUpdateType.eoout_to_received_money)
                                }
                            }
                        }
                    }
                }
                //  买单
                OtcManager.EOtcOrderOperationType.eooot_cancel_order -> {
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kOtcOdUserConfirmCancelOrderTitle), resources.getString(R.string.kOtcOdUserConfirmCancelOrderMessage)).then {
                        if (it != null && it as Boolean) {
                            guardWalletUnlocked(true) { unlocked ->
                                if (unlocked) {
                                    _execUpdateOrderCore(null, null, OtcManager.EOtcOrderUpdateType.eoout_to_cancel)
                                }
                            }
                        }
                    }
                }
                OtcManager.EOtcOrderOperationType.eooot_confirm_paid -> {
                    if (_currSelectedPaymentMethod == null) {
                        showToast(resources.getString(R.string.kOtcMgrErrOrderNoPaymentMethod))
                        return
                    }
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kOtcOdUserConfirmPaidMoneyTitle), resources.getString(R.string.kOtcOdUserConfirmPaidMoneyMessage)).then {
                        if (it != null && it as Boolean) {
                            guardWalletUnlocked(true) { unlocked ->
                                if (unlocked) {
                                    _execUpdateOrderCore(_currSelectedPaymentMethod!!.getString("account"),
                                            _currSelectedPaymentMethod!!.get("type"),
                                            OtcManager.EOtcOrderUpdateType.eoout_to_paied)
                                }
                            }
                        }
                    }
                }
                OtcManager.EOtcOrderOperationType.eooot_confirm_received_refunded -> {
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kOtcOdUserConfirmReceiveRefundTitle), resources.getString(R.string.kOtcOdUserConfirmReceiveRefundMessage)).then {
                        if (it != null && it as Boolean) {
                            guardWalletUnlocked(true) { unlocked ->
                                if (unlocked) {
                                    _execUpdateOrderCore(_order_details.getString("payAccount"),
                                            _order_details.get("payChannel"),
                                            OtcManager.EOtcOrderUpdateType.eoout_to_refunded_confirm)
                                }
                            }
                        }
                    }
                }
                //  商家
                OtcManager.EOtcOrderOperationType.eooot_mc_cancel_sell_order -> {
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kOtcOdMerchantConfirmReturnAssetTitle), resources.getString(R.string.kOtcOdMerchantConfirmReturnAssetMessage)).then {
                        if (it != null && it as Boolean) {
                            _transferCoinToUserAndUpadteOrder(true, null, null,
                                    OtcManager.EOtcOrderUpdateType.eoout_to_mc_return)
                        }
                    }
                }
                OtcManager.EOtcOrderOperationType.eooot_mc_confirm_paid -> {
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kOtcOdMerchantConfirmPaidMoneyTitle), resources.getString(R.string.kOtcOdMerchantConfirmPaidMoneyMessage)).then {
                        if (it != null && it as Boolean) {
                            guardWalletUnlocked(true) { unlocked ->
                                if (unlocked) {
                                    _execUpdateOrderCore(_currSelectedPaymentMethod!!.getString("account"),
                                            _currSelectedPaymentMethod!!.get("type"),
                                            OtcManager.EOtcOrderUpdateType.eoout_to_mc_paied)
                                }
                            }
                        }
                    }
                }
                OtcManager.EOtcOrderOperationType.eooot_mc_confirm_received_money -> {
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kOtcOdMerchantConfirmReceiveMoneyTitle), resources.getString(R.string.kOtcOdMerchantConfirmReceiveMoneyMessage)).then {
                        if (it != null && it as Boolean) {
                            _transferCoinToUserAndUpadteOrder(false, _order_details.getString("payAccount"), _order_details.get("payChannel"),
                                    OtcManager.EOtcOrderUpdateType.eoout_to_mc_received_money)
                        }
                    }
                }
                OtcManager.EOtcOrderOperationType.eooot_mc_cancel_buy_order -> {
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kOtcOdMerchantConfirmRefundMoneyTitle), resources.getString(R.string.kOtcOdMerchantConfirmRefundMoneyMessage)).then {
                        if (it != null && it as Boolean) {
                            guardWalletUnlocked(true) { unlocked ->
                                if (unlocked) {
                                    _execUpdateOrderCore(_order_details.getString("payAccount"),
                                            _order_details.get("payChannel"),
                                            OtcManager.EOtcOrderUpdateType.eoout_to_mc_cancel)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     *  (private) 执行更新订单。确认付款/取消订单/商家退款（用户收到退款后取消订单）等
     */
    private fun _execUpdateOrderCore(payAccount: String?, payChannel: Any?, type: OtcManager.EOtcOrderUpdateType, signatureTx: JSONObject? = null, prev_mask: ViewMask? = null) {
        assert(!WalletManager.sharedWalletManager().isLocked())

        val mask = prev_mask
                ?: ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }

        val otc = OtcManager.sharedOtcManager()
        val userAccount = otc.getCurrentBtsAccount()
        val orderId = _order_details.getString("orderId")
        val p1 = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
            otc.updateUserOrder(userAccount, orderId, payAccount, payChannel, type)
        } else {
            otc.updateMerchantOrder(userAccount, orderId, payAccount, payChannel, type, signatureTx)
        }

        p1.then {
            //  设置：订单状态已变更标记
            _orderStatusDirty = true
            //  停止付款计时器
            _stopPaymentTimer()
            //  更新状态成功、刷新界面。
            val queryPromise = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                otc.queryUserOrderDetails(userAccount, orderId)
            } else {
                otc.queryMerchantOrderDetails(userAccount, orderId)
            }
            return@then queryPromise.then {
                //  获取新订单数据成功
                mask.dismiss()
                val details_responsed = it as? JSONObject
                _refreshUI(details_responsed?.optJSONObject("data"))
                return@then null
            }
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }

    }

    /**
     *  (private) 执行转币
     */
    private fun _execTransferCore() {
        guardWalletUnlocked(true) { unlocked ->
            if (unlocked) {
                val userAccount = OtcManager.sharedOtcManager().getCurrentBtsAccount()
                val otcAccount = _order_details.getString("otcAccount")
                val assetSymbol = _order_details.getString("assetSymbol")
                val args_amount = _order_details.getString("quantity")

                //  REMARK：转账memo格式：F(发币)T(退币) + 订单号后10位
                val orderId = _order_details.getString("orderId")
                val args_memo_str = "F${orderId.substring(max(orderId.length - 10, 0))}"

                val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
                mask.show()

                val chainMgr = ChainObjectManager.sharedChainObjectManager()
                val p1 = chainMgr.queryFullAccountInfo(userAccount)
                val p2 = chainMgr.queryAccountData(otcAccount)
                val p3 = chainMgr.queryAssetData(assetSymbol)
                //  TODO:2.9 100? args
                val p4 = chainMgr.queryAccountHistoryByOperations(userAccount, jsonArrayfrom(EBitsharesOperations.ebo_transfer.value), 100)
                Promise.all(p1, p2, p3, p4).then {
                    val promise_data_array = it as? JSONArray
                    val full_from_account = promise_data_array?.optJSONObject(0)
                    val to_account = promise_data_array?.optJSONObject(1)
                    val asset = promise_data_array?.optJSONObject(2)
                    val his_data_array = promise_data_array?.optJSONArray(3)
                    if (full_from_account == null || to_account == null || asset == null) {
                        mask.dismiss()
                        showToast(resources.getString(R.string.kOtcOdOrderDataException))
                        return@then null
                    }

                    val real_from_id = full_from_account.getJSONObject("account").getString("id")
                    val real_to_id = to_account.getString("id")
                    val real_amount = Utils.auxGetStringDecimalNumberValue(args_amount)
                    val real_asset_id = asset.getString("id")
                    val real_asset_precision = asset.getInt("precision")

                    //  检测是否已经转币了。
                    var bMatched = false
                    if (his_data_array != null && his_data_array.length() > 0) {
                        for (his_object in his_data_array.forin<JSONObject>()) {
                            val op = his_object!!.getJSONArray("op")
                            assert(op.getInt(0) == EBitsharesOperations.ebo_transfer.value)
                            val opdata = op.optJSONObject(1)
                            if (opdata == null) {
                                continue
                            }

                            // 1、检测from、to、amount是否匹配
                            val from_id = opdata.getString("from")
                            val to_id = opdata.getString("to")
                            if (from_id != real_from_id || to_id != real_to_id) {
                                continue
                            }

                            // 2、检测转币数量是否匹配
                            val op_amount = opdata.getJSONObject("amount")
                            if (real_asset_id != op_amount.getString("asset_id")) {
                                continue
                            }
                            val n_op_amount = bigDecimalfromAmount(op_amount.getString("amount"), real_asset_precision)
                            if (n_op_amount != real_amount) {
                                continue
                            }

                            // 3、检测memo中订单号信息是否匹配
                            val memo_object = opdata.optJSONObject("memo")
                            if (memo_object == null) {
                                continue
                            }
                            val plain_memo = WalletManager.sharedWalletManager().decryptMemoObject(memo_object)
                            if (plain_memo == null) {
                                continue
                            }
                            if (plain_memo == args_memo_str) {
                                bMatched = true
                                break
                            }
                        }
                    }

                    if (bMatched) {
                        //  已转过币了：仅更新订单状态
                        _execUpdateOrderCore(null, null, OtcManager.EOtcOrderUpdateType.eoout_to_transferred, prev_mask = mask)
                    } else {
                        //  转币 & 更新订单状态
                        BitsharesClientManager.sharedBitsharesClientManager().simpleTransfer2(this, full_from_account, to_account, asset,
                                args_amount, args_memo_str, null, null, true).then {
                            val tx_data = it as JSONObject
                            val err = tx_data.optString("err", null)
                            if (err != null) {
                                mask.dismiss()
                                showToast(err)
                            } else {
                                //  转币成功：更新订单状态
                                _execUpdateOrderCore(null, null, OtcManager.EOtcOrderUpdateType.eoout_to_transferred, prev_mask = mask)
                            }
                        }.catch { err ->
                            mask.dismiss()
                            showGrapheneError(err)
                        }
                    }
                    return@then null
                }.catch {
                    mask.dismiss()
                    showToast(resources.getString(R.string.tip_network_error))
                }
            }
        }
    }

    private fun _transferCoinToUserAndUpadteOrder(return_coin_to_user: Boolean, payAccount: String?, payChannel: Any?, type: OtcManager.EOtcOrderUpdateType) {
        guardWalletUnlocked(true) { unlocked ->
            if (unlocked) {
                val otc = OtcManager.sharedOtcManager()
                val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
                otc.queryMerchantMemoKey(otc.getCurrentBtsAccount()).then {
                    val responsed = it as? JSONObject
                    val priKey = responsed?.opt("data") as? String
                    val pubKey = OrgUtils.genBtsAddressFromWifPrivateKey(priKey ?: "")
                    if (pubKey == null) {
                        mask.dismiss()
                        showToast(resources.getString(R.string.kTxInvalidMemoPriKey))
                        return@then null
                    }
                    //  签名
                    _genTransferTransactionObject(return_coin_to_user, JSONObject().apply {
                        put(pubKey, priKey)
                    }).then {
                        val tx_data = it as JSONObject
                        val err = tx_data.optString("err", null)
                        if (err != null) {
                            //  错误
                            mask.dismiss()
                            showToast(err)
                        } else {
                            //  转账签名成功
                            val tx = tx_data.getJSONObject("tx")
                            //  更新订单状态
                            _execUpdateOrderCore(payAccount, payChannel, type, signatureTx = tx, prev_mask = mask)
                        }
                        return@then null
                    }.catch { err ->
                        mask.dismiss()
                        showGrapheneError(err)
                    }
                    return@then null
                }.catch { err ->
                    mask.dismiss()
                    otc.showOtcError(this, err)
                }
            }
        }
    }

    /**
     *  (private) 生成转账数据结构。商家已签名的。
     */
    private fun _genTransferTransactionObject(return_coin_to_user: Boolean, memo_extra_keys: JSONObject?): Promise {
        val walletMgr = WalletManager.sharedWalletManager()
        assert(!walletMgr.isLocked())

        val userAccount = _order_details.getString("userAccount")
        val otcAccount = _order_details.getString("otcAccount")
        val assetSymbol = _order_details.getString("assetSymbol")
        val args_amount = _order_details.getString("quantity")

        //  REMARK：转账memo格式：F(发币)T(退币) + 订单号后10位
        val orderId = _order_details.getString("orderId")
        val prefix = if (return_coin_to_user) "T" else "F"
        val args_memo_str = "$prefix${orderId.substring(max(orderId.length - 10, 0))}"

        //  获取用户自身的KEY进行签名。
        val active_permission = walletMgr.getWalletAccountInfo()!!.getJSONObject("account").getJSONObject("active")
        val sign_pub_keys = walletMgr.getSignKeys(active_permission, false)

        return BitsharesClientManager.sharedBitsharesClientManager().simpleTransfer(this, otcAccount, userAccount, assetSymbol,
                args_amount, args_memo_str, memo_extra_keys, sign_pub_keys, false)
    }

}
