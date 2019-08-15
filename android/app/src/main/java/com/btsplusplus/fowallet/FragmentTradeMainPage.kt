package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import kotlin.math.pow

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentTradeMainPage.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentTradeMainPage.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentTradeMainPage : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _isbuy: Boolean = true
    lateinit var _view: View
    lateinit var _ctx: Context
    private lateinit var _viewBidAsk: ViewBidAsk
    lateinit var _tradingPair: TradingPair
    private var _balanceData: JSONObject? = null
    private lateinit var _base_amount_n: BigDecimal
    private lateinit var _quote_amount_n: BigDecimal
    private var _currLimitOrders: JSONObject? = null
    private var _userOrderDataArray: List<JSONObject>? = null

    private lateinit var _tf_price_watcher: UtilsDigitTextWatcher
    private lateinit var _tf_amount_watcher: UtilsDigitTextWatcher
    private lateinit var _tf_total_watcher: UtilsDigitTextWatcher

    override fun onInitParams(args: Any?) {
        val json_array = args as JSONArray
        _isbuy = json_array.getBoolean(0)
        _tradingPair = json_array.get(1) as TradingPair
    }

    /**
     *  事件 - 处理登录成功事件
     *  更改 登录按钮为 买卖按钮
     *  获取 个人信息
     */
    fun onRefreshLoginStatus() {
        _view.findViewById<TextView>(R.id.confirmation_btn_of_buy).tap {
            if (_isbuy) {
                it.text = "${R.string.kBtnBuy.xmlstring(_ctx)}${_tradingPair._quoteAsset.getString("symbol")}"
            } else {
                it.text = "${R.string.kBtnSell.xmlstring(_ctx)}${_tradingPair._quoteAsset.getString("symbol")}"
            }
        }
    }

    /**
     *  事件 - 成交历史数据更新
     */
    fun onQueryFillOrderHistoryResponsed(data_array: JSONArray?) {
        if (!isAdded) {
            return
        }
        if (data_array != null && data_array.length() > 0) {
            //  更新最新成交价
            _refreshLatestPrice(!data_array.first<JSONObject>()!!.getBoolean("issell"))
        }
    }

    private fun _genBalanceInfos(full_account_data: JSONObject): JSONObject {
        val new_balances_array = JSONArray()

        var base_balance: JSONObject? = null
        var quote_balance: JSONObject? = null

        //  初始化 base_balance 和 quote_balance 信息，并统计余额信息。（REMARK：get_account_balances 和 get_full_accounts 的余额信息 key 不一致。）
        val balances_array = full_account_data.getJSONArray("balances")
        var found_inc: Int = 0
        balances_array.forEach<JSONObject> {
            val balance = it!!
            val asset_id = balance.getString("asset_type")
            val amount = balance.getString("balance")
            //  统一余额等 key 为：asset_id 和 amount。
            new_balances_array.put(jsonObjectfromKVS("asset_id", asset_id, "amount", amount))
            //  初始化 base 和 quote
            if (found_inc < 2) {
                if (asset_id == _tradingPair._baseId) {
                    base_balance = new_balances_array.last<JSONObject>()
                    ++found_inc
                } else if (asset_id == _tradingPair._quoteId) {
                    quote_balance = new_balances_array.last<JSONObject>()
                    ++found_inc
                }
            }
        }

        //  用户没有对应的资产，则初始化默认值为 0。
        if (base_balance == null) {
            base_balance = jsonObjectfromKVS("asset_id", _tradingPair._baseId, "amount", 0)
        }
        if (quote_balance == null) {
            quote_balance = jsonObjectfromKVS("asset_id", _tradingPair._quoteId, "amount", 0)
        }

        //  计算手续费对象（如果手续资产是base或者quote之一，则更新资产的可用余额，即减去手续费需要的amount）
        val fee_item = ChainObjectManager.sharedChainObjectManager().estimateFeeObject(EBitsharesOperations.ebo_limit_order_create.value, new_balances_array)
        val fee_asset_id = fee_item.getString("fee_asset_id")
        if (fee_asset_id == _tradingPair._baseId) {
            val old = base_balance!!.getString("amount").toDouble()
            val fee = fee_item.getString("amount").toDouble()
            if (old >= fee) {
                base_balance!!.put("amount", old - fee)
            } else {
                base_balance!!.put("amount", 0)
            }
            base_balance!!.put("total_amount", old)
        } else if (fee_asset_id == _tradingPair._quoteId) {
            val old = quote_balance!!.getString("amount").toDouble()
            val fee = fee_item.getString("amount").toDouble()
            if (old >= fee) {
                quote_balance!!.put("amount", old - fee)
            } else {
                quote_balance!!.put("amount", 0)
            }
            quote_balance!!.put("total_amount", old)
        }

        //  构造余额信息 {base:{asset_id, amount}, quote:{asset_id, amount}, all_balances:[{asset_id, amount}, ...], fee_item:{...}}
        return jsonObjectfromKVS("base", base_balance!!, "quote", quote_balance!!,
                "all_balances", new_balances_array, "fee_item", fee_item, "full_account_data", full_account_data)
    }

    fun onFullAccountDataResponsed(full_account_data: JSONObject?) {
        if (!isAdded) {
            return
        }
        //  未登录的情况，待处理。
        if (full_account_data == null) {
            return
        }

        //  1、保存余额信息、同步更新 base 数量 和 quote 数量。
        _balanceData = _genBalanceInfos(full_account_data)
        //  !!! 一定要同步更新 ！！！
        _base_amount_n = bigDecimalfromAmount(_balanceData!!.getJSONObject("base").getString("amount"), _tradingPair._basePrecision)
        _quote_amount_n = bigDecimalfromAmount(_balanceData!!.getJSONObject("quote").getString("amount"), _tradingPair._quotePrecision)

        if (_isbuy) {
            //  买的情况：显示 base 的余额
            _draw_ui_available(_base_amount_n.toPriceAmountString(), true, _isbuy)
        } else {
            //  卖的情况：显示 quote 的余额
            _draw_ui_available(_quote_amount_n.toPriceAmountString(), true, _isbuy)
        }

        //  刷新手续费信息
        _draw_market_fee(if (_isbuy) _tradingPair._quoteAsset else _tradingPair._baseAsset, full_account_data.getJSONObject("account"))

        //  2、刷新交易额、可用余额等
        _onPriceOrAmountChanged()

        //  3、当前委托信息
        _userOrderDataArray = genCurrentLimitOrderData(full_account_data.getJSONArray("limit_orders"))
        _refreshCurrentOrderFileds()

        //  3.1、订阅委托状态变化
        val order_ids = JSONArray()
        _userOrderDataArray!!.forEach {
            order_ids.put(it.getString("id"))
        }
        val account_id = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account").getString("id")
        ScheduleManager.sharedScheduleManager().sub_market_monitor_orders(_tradingPair, order_ids, account_id)
    }

    /**
     * 事件 - ticker数据更新
     */
    fun onQueryTickerDataResponse(ticker_data: JSONObject) {
        if (!isAdded) {
            return
        }
        _refreshLatestPrice(true)
    }

    fun onQueryOrderBookResponse(limit_orders: JSONObject) {
        if (!isAdded) {
            return
        }
        //  保存
        _currLimitOrders = limit_orders
        //  更新显示精度
        _tradingPair.dynamicUpdateDisplayPrecision(limit_orders)
        //  刷新盘口买卖信息
        _viewBidAsk.refreshWithData(limit_orders)
        //  价格输入框没有值的情况设置默认值 买界面-默认卖1价格 卖界面-默认买1价（参考huobi）
        val tf = _view.findViewById<EditText>(R.id.tf_price)
        val str_price = tf.text.toString()
        if (str_price == "") {
            var data: JSONObject? = null
            if (_isbuy) {
                data = limit_orders.getJSONArray("asks").first<JSONObject>()
            } else {
                data = limit_orders.getJSONArray("bids").first<JSONObject>()
            }
            if (data != null) {
                _tf_price_watcher.set_new_text(OrgUtils.formatFloatValue(data.getString("price").toDouble(), _tradingPair._displayPrecision, false))
                _onPriceOrAmountChanged()
            }
        }
    }

    /**
     * (private) 输入的价格 or 数量发生变化，评估交易额。
     */
    private fun _onPriceOrAmountChanged() {
        if (_balanceData == null) {
            return
        }
        val str_price = _tf_price_watcher.get_tf_string()
        val str_amount = _tf_amount_watcher.get_tf_string()

        //  获取单价、数量、总价

        //  !!! 精确计算 !!!
        val n_price = Utils.auxGetStringDecimalNumberValue(str_price)
        val n_amount = Utils.auxGetStringDecimalNumberValue(str_amount)
        val n_total = n_price.multiply(n_amount).setScale(_tradingPair._basePrecision, if (_isbuy) {
            BigDecimal.ROUND_UP
        } else {
            BigDecimal.ROUND_DOWN
        })

        if (_isbuy) {
            _draw_ui_available(_base_amount_n.toPriceAmountString(), _base_amount_n >= n_total, _isbuy)
        } else {
            _draw_ui_available(_quote_amount_n.toPriceAmountString(), _quote_amount_n >= n_amount, _isbuy)
        }

        //  总金额
        if (str_price == "" || str_amount == "") {
            _tf_total_watcher.clear()
        } else {
            _tf_total_watcher.set_new_text(OrgUtils.formatFloatValue(n_total.toDouble(), _tradingPair._displayPrecision, false))
        }
    }

    private fun _draw_market_fee(asset: JSONObject, account: JSONObject? = null) {
        val market_fee_percent = asset.optJSONObject("options")?.optString("market_fee_percent", null)
        if (market_fee_percent != null) {
            val n_market_fee_percent = bigDecimalfromAmount(market_fee_percent, BigDecimal.valueOf(10.0.pow(2)))
//            if (account != null && Utils.isBitsharesVIP(account.optString("membership_expiration_date", null))) {
//            } else {
//            }
            _view.findViewById<TextView>(R.id.label_txt_market_fee).text = String.format(resources.getString(R.string.kLabelMarketFee), "${n_market_fee_percent.toPlainString()}%")
        } else {
            _view.findViewById<TextView>(R.id.label_txt_market_fee).text = String.format(resources.getString(R.string.kLabelMarketFee), "0%")
        }
    }

    private fun _draw_ui_available(value: String?, enough: Boolean, isbuy: Boolean) {
        val symbol: String
        val not_enough_str: String
        val value_str: String
        val value_color: Int

        if (isbuy) {
            symbol = _tradingPair._baseAsset.getString("symbol")
            not_enough_str = resources.getString(R.string.kVcTradeTipAvailableNotEnough)
        } else {
            symbol = _tradingPair._quoteAsset.getString("symbol")
            not_enough_str = resources.getString(R.string.kVcTradeTipAmountNotEnough)
        }

        if (enough) {
            value_str = "${value ?: "--"}$symbol"
            value_color = R.color.theme01_textColorNormal
        } else {
            value_str = "${value ?: "--"}$symbol($not_enough_str)"
            value_color = R.color.theme01_tintColor
        }

        _view.findViewById<TextView>(R.id.label_txt_available_n).tap {
            it.text = "${resources.getString(R.string.kLableAvailable)} $value_str"
            it.setTextColor(resources.getColor(value_color))
        }
    }

    /**
     * 刷新价格和百分比信息
     */
    private fun _refreshLatestPrice(isbuy: Boolean) {
        var latest = "--"
        var percent = "0"
        val ticker_data = ChainObjectManager.sharedChainObjectManager().getTickerData(_tradingPair._baseAsset.getString("symbol"), _tradingPair._quoteAsset.getString("symbol"))
        if (ticker_data != null) {
            latest = OrgUtils.formatFloatValue(ticker_data.getString("latest").toDouble(), _tradingPair._basePrecision)
            percent = ticker_data.getString("percent_change")
        }
        //  price
        val label_txt_curr_price = _view.findViewById<TextView>(R.id.label_txt_curr_price)
        label_txt_curr_price.text = latest
        if (isbuy) {
            label_txt_curr_price.setTextColor(resources.getColor(R.color.theme01_buyColor))
        } else {
            label_txt_curr_price.setTextColor(resources.getColor(R.color.theme01_sellColor))
        }
        //  percent
        val label_txt_curr_price_percent = _view.findViewById<TextView>(R.id.label_txt_curr_price_percent)
        val percent_value = percent.toDouble()
        if (percent_value > 0) {
            label_txt_curr_price_percent.text = "+${percent}%"
            label_txt_curr_price_percent.setTextColor(resources.getColor(R.color.theme01_buyColor))
        } else if (percent_value < 0) {
            label_txt_curr_price_percent.text = "${percent}%"
            label_txt_curr_price_percent.setTextColor(resources.getColor(R.color.theme01_sellColor))
        } else {
            label_txt_curr_price_percent.text = "${percent}%"
            label_txt_curr_price_percent.setTextColor(resources.getColor(R.color.theme01_zeroColor))
        }
    }

    /**
     * 描绘当前委托信息
     */
    private fun _refreshCurrentOrders(orders: List<JSONObject>?) {
        val ly: LinearLayout = _view.findViewById(R.id.layout_my_current_order)
        ly.removeAllViews()

        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(24f))
        layout_params.gravity = Gravity.CENTER_VERTICAL
        if (orders == null || orders.size == 0) {
            ly.addView(createNoOrderView(_ctx))
        } else {
            orders.forEach { order ->
                ViewUtils.createCellForOrder(_ctx, layout_params, ly, order) {
                    onButtonClicked_CancelOrder(it)
                }
            }
        }
    }

    /**
     * 交易：取消订单
     */
    private fun onButtonClicked_CancelOrder(order: JSONObject) {
        val order_id = order.getString("id")
        val raw_order = order.getJSONObject("raw_order")
        val extra_balance = JSONObject().apply {
            put(raw_order.getJSONObject("sell_price").getJSONObject("base").getString("asset_id"), raw_order.getString("for_sale"))
        }
        val fee_item = ChainObjectManager.sharedChainObjectManager().getFeeItem(EBitsharesOperations.ebo_limit_order_cancel, _balanceData!!.getJSONObject("full_account_data"), extra_balance = extra_balance)
        if (!fee_item.getBoolean("sufficient")) {
            showToast(_ctx.resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }
        //  --- 参数校验完毕开始执行请求 ---
        activity!!.guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                processCancelOrderCore(fee_item, order_id)
            }
        }
    }

    private fun processCancelOrderCore(fee_item: JSONObject, order_id: String) {
        val fee_asset_id = fee_item.getString("fee_asset_id")
        val account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        val account_id = account_data.getString("id")

        val op = jsonObjectfromKVS("fee", jsonObjectfromKVS("amount", 0, "asset_id", fee_asset_id),
                "fee_paying_account", account_id,
                "order", order_id)

        //  确保有权限发起普通交易，否则作为提案交易处理。
        activity!!.GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_limit_order_cancel, false, false,
                op, account_data) { isProposal, _ ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this.activity!!), this.activity!!)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().cancelLimitOrders(jsonArrayfrom(op)).then {
                ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_id).then {
                    mask.dismiss()
                    //  刷新（调用owner的方法刷新、买/卖界面都需要刷新。）
                    getOwner<ActivityTradeMain>()?.onFullAccountInfoResponsed(it as JSONObject)

                    showToast(String.format(resources.getString(R.string.kVcOrderTipTxCancelFullOK), order_id))
                    //  [统计]
                    btsppLogCustom("txCancelLimitOrderFullOK", jsonObjectfromKVS("account", account_id))
                    return@then null
                }.catch {
                    mask.dismiss()
                    showToast(String.format(resources.getString(R.string.kVcOrderTipTxCancelOK), order_id))
                    //  [统计]
                    btsppLogCustom("txCancelLimitOrderOK", jsonObjectfromKVS("account", account_id))
                }
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txCancelLimitOrderFailed", jsonObjectfromKVS("account", account_id))
            }
        }
    }

    /**
     * 价格输入框和数量输入框尾部按钮点击事件
     */
    private fun _onTailerButtonClicked_Bid1() {
        if (_currLimitOrders != null) {
            val data = _currLimitOrders!!.getJSONArray("bids").first<JSONObject>()
            if (data != null) {
                _tf_price_watcher.set_new_text(OrgUtils.formatFloatValue(data.getString("price").toDouble(), _tradingPair._displayPrecision, false))
                _onPriceOrAmountChanged()
            }
        }
    }

    private fun _onTailerButtonClicked_Ask1() {
        if (_currLimitOrders != null) {
            val data = _currLimitOrders!!.getJSONArray("asks").first<JSONObject>()
            if (data != null) {
                _tf_price_watcher.set_new_text(OrgUtils.formatFloatValue(data.getString("price").toDouble(), _tradingPair._displayPrecision, false))
                _onPriceOrAmountChanged()
            }
        }
    }

    private fun _onTailerButtonClicked_percent(percent: BigDecimal) {
        if (_balanceData == null) {
            if (!WalletManager.sharedWalletManager().isWalletExist()) {
                showToast(resources.getString(R.string.kVcTradeTipPleaseLoginFirst))
            }
            return
        }
        if (_isbuy) {
            //  买入：数量 = base的数量 / 单价    REMARK：如果单价为空则不处理。
            val str_price = _tf_price_watcher.get_tf_string()
            if (str_price != "") {
                //  获取单价（<=0则不处理）
                val n_price = Utils.auxGetStringDecimalNumberValue(str_price)
                if (n_price.compareTo(BigDecimal.ZERO) > 0) {
                    //  保留小数位数 向下取整
                    var buy_amount = _base_amount_n.divide(n_price, _tradingPair._numPrecision, BigDecimal.ROUND_DOWN)
                    buy_amount = buy_amount.multiply(percent).setScale(_tradingPair._numPrecision, BigDecimal.ROUND_DOWN)
                    //  设置
                    _tf_amount_watcher.set_new_text(OrgUtils.formatFloatValue(buy_amount.toDouble(), _tradingPair._numPrecision, false))
                    _onPriceOrAmountChanged()
                }
            }
        } else {
            //  卖出：数量 = quote 的数量。

            //  保留小数位数 向下取整
            val sell_amount = _quote_amount_n.multiply(percent).setScale(_tradingPair._numPrecision, BigDecimal.ROUND_DOWN)

            //  设置
            _tf_amount_watcher.set_new_text(sell_amount.toString())
            _onPriceOrAmountChanged()
        }
    }

    private fun onSubmitClicked() {
        if (WalletManager.sharedWalletManager().isWalletExist()) {
            onBuyOrSellActionClicked()
        } else {
            activity!!.goTo(ActivityLogin::class.java, true)
        }
    }

    /**
     * 核心 处理买卖操作
     */
    private fun onBuyOrSellActionClicked() {
        if (_balanceData == null) {
            showToast(resources.getString(R.string.kVcTradeSubmitTipNoData))
            return
        }
        if (!_balanceData!!.getJSONObject("fee_item").getBoolean("sufficient")) {
            showToast(_ctx.resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }

        val str_price = _tf_price_watcher.get_tf_string()
        val str_amount = _tf_amount_watcher.get_tf_string()
        if (str_price == "") {
            showToast(resources.getString(R.string.kVcTradeSubmitTipPleaseInputPrice))
            return
        }
        if (str_amount == "") {
            showToast(resources.getString(R.string.kVcTradeSubmitTipPleaseInputAmount))
            return
        }

        //  获取单价、数量、总价

        //  !!! 精确计算 !!!
        val n_price = Utils.auxGetStringDecimalNumberValue(str_price)
        val n_amount = Utils.auxGetStringDecimalNumberValue(str_amount)
        val n_zero = BigDecimal.ZERO
        if (n_price.compareTo(n_zero) <= 0) {
            showToast(resources.getString(R.string.kVcTradeSubmitTipPleaseInputPrice))
            return
        }
        if (n_amount.compareTo(n_zero) <= 0) {
            showToast(resources.getString(R.string.kVcTradeSubmitTipPleaseInputAmount))
            return
        }

        //  小数位数同 base 资产精度相同：
        //  买入行为：总金额向上取整
        //  卖出行为：向下取整
        val n_total = n_price.multiply(n_amount).setScale(_tradingPair._basePrecision, if (_isbuy) {
            BigDecimal.ROUND_UP
        } else {
            BigDecimal.ROUND_DOWN
        })
        if (n_total.compareTo(n_zero) <= 0) {
            showToast(resources.getString(R.string.kVcTradeSubmitTotalTooLow))
            return
        }

        if (_isbuy) {
            //  买的总金额
            if (_base_amount_n.compareTo(n_total) < 0) {
                showToast(resources.getString(R.string.kVcTradeSubmitTotalNotEnough))
                return
            }
        } else {
            if (_quote_amount_n.compareTo(n_amount) < 0) {
                showToast(resources.getString(R.string.kVcTradeSubmitAmountNotEnough))
                return
            }
        }

        //  --- 参数校验完毕开始执行请求 ---
        activity!!.guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                processBuyOrSellActionCore(n_price, n_amount, n_total)
            }
        }
    }

    /**
     * 处理买卖核心
     */
    private fun processBuyOrSellActionCore(n_price: BigDecimal, n_amount: BigDecimal, n_total: BigDecimal) {
        val amount_to_sell: JSONObject
        val min_to_receive: JSONObject

        if (_isbuy) {
            //  执行买入    base减少 -> quote增加

            //  得到数量（向上取整）
            val n_gain_total = n_amount.scaleByPowerOfTen(_tradingPair._quotePrecision).setScale(0, BigDecimal.ROUND_UP)
            min_to_receive = jsonObjectfromKVS("asset_id", _tradingPair._quoteId, "amount", n_gain_total.toPlainString())

            //  卖出数量等于 买的总花费金额 = 单价*买入数量（向下取整）  REMARK：这里 n_total <= _base_amount_n
            val n_buy_total = n_total.scaleByPowerOfTen(_tradingPair._basePrecision).setScale(0, BigDecimal.ROUND_DOWN)
            amount_to_sell = jsonObjectfromKVS("asset_id", _tradingPair._baseId, "amount", n_buy_total.toPlainString())
        } else {
            //  执行卖出    quote减少 -> base增加

            //  卖出数量不能超过总数量（向下取整）                   REMARK：这里 n_amount <= _quote_amount_n
            val n_sell_amount = n_amount.scaleByPowerOfTen(_tradingPair._quotePrecision).setScale(0, BigDecimal.ROUND_DOWN)
            amount_to_sell = jsonObjectfromKVS("asset_id", _tradingPair._quoteId, "amount", n_sell_amount.toPlainString())

            //  得到数量等于 单价*卖出数量（向上取整）
            val n_gain_total = n_total.scaleByPowerOfTen(_tradingPair._basePrecision).setScale(0, BigDecimal.ROUND_UP)
            min_to_receive = jsonObjectfromKVS("asset_id", _tradingPair._baseId, "amount", n_gain_total.toPlainString())
        }

        //  构造限价单 op 结构体
        val account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        val seller = account_data.getString("id")
        val fee_item = _balanceData!!.getJSONObject("fee_item")
        val now_sec = Utils.now_ts()
        val expiration_ts = now_sec + 64281600L     //  两年后：64281600 = 3600*24*31*12*2

        val op = jsonObjectfromKVS("fee", jsonObjectfromKVS("amount", 0, "asset_id", fee_item.getString("fee_asset_id")),
                "seller", seller,                   //  买卖帐号
                "amount_to_sell", amount_to_sell,   //  卖出数量
                "min_to_receive", min_to_receive,   //  得到数量
                "expiration", expiration_ts,        //  订单过期日期 格式：2018-06-04T13:03:57
                "fill_or_kill", false)

        //  确保有权限发起普通交易，否则作为提案交易处理。
        activity!!.GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_limit_order_create, false, false,
                op, account_data) { isProposal, _ ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this.activity!!), this.activity!!)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().createLimitOrder(op).then {
                //  刷新UI（清除输入框）
                _tf_amount_watcher.clear()
                //  获取新的限价单ID号（考虑到数据结构可能变更，加各种safe判断。）
                val new_order_id = OrgUtils.extractNewObjectID(it as? JSONArray)
                ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(seller).then {
                    mask.dismiss()
                    //  刷新（调用owner的方法刷新、买/卖界面都需要刷新。）
                    getOwner<ActivityTradeMain>()?.onFullAccountInfoResponsed(it as JSONObject)
                    //  获取刚才新创建的限价单
                    var new_order: JSONObject? = null
                    if (new_order_id != null) {
                        for (order in _userOrderDataArray!!) {
                            if (order.getString("id") == new_order_id) {
                                new_order = order
                                break
                            }
                        }
                    }
                    if (new_order != null || new_order_id == null) {
                        //  尚未成交则添加到监控
                        if (new_order_id != null) {
                            val account_id = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account").getString("id")
                            ScheduleManager.sharedScheduleManager().sub_market_monitor_orders(_tradingPair, jsonArrayfrom(new_order_id), account_id)
                        }
                        showToast(resources.getString(R.string.kVcTradeTipTxCreateFullOK))
                    } else {
                        showToast(String.format(resources.getString(R.string.kVcTradeTipTxCreateFullOKWithID), new_order_id))
                    }
                    //  [统计]
                    btsppLogCustom("txCreateLimitOrderFullOK", jsonObjectfromKVS("account", seller, "isbuy", _isbuy,
                            "base", _tradingPair._baseAsset.getString("symbol"), "quote", _tradingPair._quoteAsset.getString("symbol")))
                    return@then null
                }.catch {
                    //  刷新失败也添加到监控
                    if (new_order_id != null) {
                        val account_id = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account").getString("id")
                        ScheduleManager.sharedScheduleManager().sub_market_monitor_orders(_tradingPair, jsonArrayfrom(new_order_id), account_id)
                    }
                    mask.dismiss()
                    showToast(resources.getString(R.string.kVcTradeTipTxCreateOK))
                    //  [统计]
                    btsppLogCustom("txCreateLimitOrderOK", jsonObjectfromKVS("account", seller, "isbuy", _isbuy,
                            "base", _tradingPair._baseAsset.getString("symbol"), "quote", _tradingPair._quoteAsset.getString("symbol")))
                }
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txCreateLimitOrderFailed", jsonObjectfromKVS("account", seller, "isbuy", _isbuy,
                        "base", _tradingPair._baseAsset.getString("symbol"), "quote", _tradingPair._quoteAsset.getString("symbol")))
            }
        }
    }

    /**
     * 价格输入框：文本变化
     */
    private fun _onTfPriceChanged(str: String) {
        _onPriceOrAmountChanged()
    }

    /**
     * 数量输入框：文本变化
     */
    private fun _onTfAmountChanged(str: String) {
        _onPriceOrAmountChanged()
    }

    /**
     * 交易额输入框：文本变化
     */
    private fun _onTfTotalChanged(str: String) {
        if (_balanceData == null) {
            return
        }
        val str_price = _tf_price_watcher.get_tf_string()
        val n_price = Utils.auxGetStringDecimalNumberValue(str_price)

        if (n_price > BigDecimal.ZERO) {
            val str_total = _tf_total_watcher.get_tf_string()
            val n_total = Utils.auxGetStringDecimalNumberValue(str_total)
            val n_amount = n_total.divide(n_price, _tradingPair._quotePrecision, BigDecimal.ROUND_DOWN)

            //  刷新可用余额
            if (_isbuy) {
                _draw_ui_available(_base_amount_n.toPriceAmountString(), _base_amount_n >= n_total, _isbuy)
            } else {
                _draw_ui_available(_quote_amount_n.toPriceAmountString(), _quote_amount_n >= n_amount, _isbuy)
            }

            //  交易数量
            if (str_total == "") {
                _tf_amount_watcher.clear()
            } else {
                _tf_amount_watcher.set_new_text(OrgUtils.formatFloatValue(n_amount.toDouble(), _tradingPair._quotePrecision, false))
            }
        } else {
            //  价格为0时，交易数量为空。
            _tf_amount_watcher.clear()
        }
    }

    private fun refreshUI() {
        //  第一排涨跌文字
        _refreshLatestPrice(true)

        //  子界面 买卖盘口信息 TODO:常量5
        _viewBidAsk = ViewBidAsk(_ctx).initView(20.0f, 5, _tradingPair)
        val table_wrap_layout: LinearLayout = _view.findViewById(R.id.table_wrap_of_buy)
        table_wrap_layout.addView(_viewBidAsk)

        //  输入框占位符
        val tf_price = _view.findViewById<EditText>(R.id.tf_price)
        val tf_amount = _view.findViewById<EditText>(R.id.tf_amount)
        val tf_total = _view.findViewById<EditText>(R.id.tf_total)
        if (_isbuy) {
            tf_price.hint = _ctx.resources.getString(R.string.kPlaceHolderBuyPrice)
            tf_amount.hint = _ctx.resources.getString(R.string.kPlaceHolderBuyAmount)
        } else {
            tf_price.hint = R.string.kPlaceHolderSellPrice.xmlstring(_ctx)
            tf_amount.hint = R.string.kPlaceHolderSellAmount.xmlstring(_ctx)
        }
        //  输入框输入事件监听
        _tf_price_watcher = UtilsDigitTextWatcher().set_tf(tf_price).set_precision(_tradingPair._displayPrecision)
        tf_price.addTextChangedListener(_tf_price_watcher)
        _tf_price_watcher.on_value_changed(::_onTfPriceChanged)

        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(tf_amount).set_precision(_tradingPair._numPrecision)
        tf_amount.addTextChangedListener(_tf_amount_watcher)
        _tf_amount_watcher.on_value_changed(::_onTfAmountChanged)

        _tf_total_watcher = UtilsDigitTextWatcher().set_tf(tf_total).set_precision(_tradingPair._displayPrecision)
        tf_total.addTextChangedListener(_tf_total_watcher)
        _tf_total_watcher.on_value_changed(::_onTfTotalChanged)

        //  价格输入框尾部信息
        val label_txt_tf_price_tailer = _view.findViewById<TextView>(R.id.label_txt_tf_price_tailer)
        label_txt_tf_price_tailer.text = _tradingPair._baseAsset.getString("symbol")
        _view.findViewById<Button>(R.id.btn_tailer_bid1).setOnClickListener { _onTailerButtonClicked_Bid1() }
        _view.findViewById<Button>(R.id.btn_tailer_ask1).setOnClickListener { _onTailerButtonClicked_Ask1() }

        //  数量输入框尾部信息
        val label_txt_tf_amount_tailer = _view.findViewById<TextView>(R.id.label_txt_tf_amount_tailer)
        label_txt_tf_amount_tailer.text = _tradingPair._quoteAsset.getString("symbol")
        _view.findViewById<TextView>(R.id.btn_tailer_percent25).setOnClickListener { _onTailerButtonClicked_percent(BigDecimal.valueOf(0.25)) }
        _view.findViewById<TextView>(R.id.btn_tailer_percent50).setOnClickListener { _onTailerButtonClicked_percent(BigDecimal.valueOf(0.5)) }
        _view.findViewById<TextView>(R.id.btn_tailer_percent100).setOnClickListener { _onTailerButtonClicked_percent(BigDecimal.ONE) }

        //  交易额输入框尾部信息
        val label_txt_tf_total_tailer = _view.findViewById<TextView>(R.id.label_txt_tf_total_tailer)
        label_txt_tf_total_tailer.text = _tradingPair._baseAsset.getString("symbol")

        //  可用
        _draw_ui_available(null, true, _isbuy)
        _draw_market_fee(if (_isbuy) _tradingPair._quoteAsset else _tradingPair._baseAsset)

        //  登录 or 买入 or 卖出
        val _confirmation_btn_of_buy = _view.findViewById<TextView>(R.id.confirmation_btn_of_buy)
        if (WalletManager.sharedWalletManager().isWalletExist()) {
            if (_isbuy) {
                _confirmation_btn_of_buy.text = "${R.string.kBtnBuy.xmlstring(_ctx)}${_tradingPair._quoteAsset.getString("symbol")}"
            } else {
                _confirmation_btn_of_buy.text = "${R.string.kBtnSell.xmlstring(_ctx)}${_tradingPair._quoteAsset.getString("symbol")}"
            }
        } else {
            _confirmation_btn_of_buy.text = _ctx.resources.getString(R.string.kNormalCellBtnLogin)
        }
        if (_isbuy) {
            _confirmation_btn_of_buy.setBackgroundColor(resources.getColor(R.color.theme01_buyColor))
        } else {
            _confirmation_btn_of_buy.setBackgroundColor(resources.getColor(R.color.theme01_sellColor))
        }
        _confirmation_btn_of_buy.setOnClickListener { onSubmitClicked() }

        //  当前委托
        _refreshCurrentOrderFileds()
    }

    /**
     * 刷新当前委托区域可见性，可见的情况下添加监听以及描绘订单信息
     */
    private fun _refreshCurrentOrderFileds() {
        if (_balanceData != null) {
            _view.findViewById<LinearLayout>(R.id.field_current_orders).visibility = View.VISIBLE
            _view.findViewById<TextView>(R.id.btn_view_all_orders).setOnClickListener { onAllOrderButtonClicked() }
            //  描绘当前订单信息
            _refreshCurrentOrders(_userOrderDataArray)
        } else {
            _view.findViewById<LinearLayout>(R.id.field_current_orders).visibility = View.GONE
        }
    }

    /**
     *  (private) 查看全部订单按钮点击
     */
    private fun onAllOrderButtonClicked() {
        activity!!.guardWalletExist {
            val uid = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account").getString("id")
            activity!!.viewUserLimitOrders(uid, null)
        }
    }

    /**
     * 当前订单：生成当前订单列表信息
     */
    private fun genCurrentLimitOrderData(limit_orders: JSONArray): List<JSONObject> {
        var dataArray = mutableListOf<JSONObject>()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        for (order in limit_orders) {
            val sell_price = order!!.getJSONObject("sell_price")
            val base = sell_price.getJSONObject("base")
            val quote = sell_price.getJSONObject("quote")
            val base_id = base.getString("asset_id")
            val quote_id = quote.getString("asset_id")

            var issell: Boolean
            if (base_id == _tradingPair._baseId && quote_id == _tradingPair._quoteId) {
                //  买单：卖出 CNY
                issell = false
            } else if (base_id == _tradingPair._quoteId && quote_id == _tradingPair._baseId) {
                //  卖单：卖出 BTS
                issell = true
            } else {
                //  其他交易对的订单
                continue
            }

            val base_asset = chainMgr.getChainObjectByID(base_id)
            val quote_asset = chainMgr.getChainObjectByID(quote_id)
            val base_precision = base_asset.getInt("precision")
            val quote_precision = quote_asset.getInt("precision")
            val base_value = OrgUtils.calcAssetRealPrice(base.getString("amount"), base_precision)
            val quote_value = OrgUtils.calcAssetRealPrice(quote.getString("amount"), quote_precision)

            //  REMARK: base 是卖出的资产，除以 base 则为卖价(每1个 base 资产的价格)。反正 base / quote 则为买入价。
            var price: Double
            var price_str: String
            var amount_str: String
            var total_str: String
            var base_sym: String
            var quote_sym: String
            if (!issell) {
                //  buy     price = base / quote
                price = base_value / quote_value
                price_str = OrgUtils.formatFloatValue(price, base_precision)
                val total_real = OrgUtils.calcAssetRealPrice(order.getString("for_sale"), base_precision)
                val amount_real = total_real / price
                amount_str = OrgUtils.formatFloatValue(amount_real, quote_precision)
                total_str = OrgUtils.formatAssetString(order.getString("for_sale"), base_precision)
                base_sym = base_asset.getString("symbol")
                quote_sym = quote_asset.getString("symbol")
            } else {
                //  sell    price = quote / base
                price = quote_value / base_value
                price_str = OrgUtils.formatFloatValue(price, quote_precision)
                amount_str = OrgUtils.formatAssetString(order.getString("for_sale"), base_precision)
                val for_sale_real = OrgUtils.calcAssetRealPrice(order.getString("for_sale"), base_precision)
                val total_real = price * for_sale_real
                total_str = OrgUtils.formatFloatValue(total_real, quote_precision)
                base_sym = quote_asset.getString("symbol")
                quote_sym = base_asset.getString("symbol")
            }
            //  REMARK：特殊处理，如果按照 base or quote 的精度格式化出价格为0了，则扩大精度重新格式化。
            if (price_str == "0") {
                price_str = OrgUtils.formatFloatValue(price, 8)
            }
            val data_item = jsonObjectfromKVS("time", order.getString("expiration"),
                    "issell", issell, "price", price_str,
                    "amount", amount_str, "total", total_str,
                    "base_symbol", base_sym, "quote_symbol", quote_sym,
                    "id", order.getString("id"),
                    "seller", order.getString("seller"),
                    "raw_order", order)
            dataArray.add(data_item)
        }
        //  按照ID降序
        dataArray.sortByDescending { it.getString("id") }
        return dataArray
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        _view = inflater.inflate(R.layout.fragment_main_buy, container, false)
        _ctx = inflater.context
        refreshUI()
        return _view
    }

    fun createNoOrderView(ctx: Context): TextView {
        val tv = TextView(ctx)
        tv.text = R.string.kLabelNoOrder.xmlstring(ctx)
        tv.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv.setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
        tv.setPadding(0, Utils.toDp(40f, ctx.resources), 0, 0)
        tv.gravity = Gravity.CENTER
        return tv
    }


    // TODO: Rename method, update argument and hook method into UI event
    fun onButtonPressed(uri: Uri) {
        listener?.onFragmentInteraction(uri)
    }

//    override fun onAttach(context: Context) {
//        super.onAttach(context)
//        if (context is OnFragmentInteractionListener) {
//            listener = context
//        } else {
//            throw RuntimeException(context.toString() + " must implement OnFragmentInteractionListener")
//        }
//    }

    override fun onDetach() {
        super.onDetach()
        listener = null
    }

    /**
     * This interface must be implemented by activities that contain this
     * fragment to allow an interaction in this fragment to be communicated
     * to the activity and potentially other fragments contained in that
     * activity.
     *
     *
     * See the Android Training lesson [Communicating with Other Fragments]
     * (http://developer.android.com/training/basics/fragments/communicating.html)
     * for more information.
     */
    interface OnFragmentInteractionListener {
        // TODO: Update argument type and name
        fun onFragmentInteraction(uri: Uri)
    }
}
