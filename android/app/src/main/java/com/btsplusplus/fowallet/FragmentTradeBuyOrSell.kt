package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.*
import android.view.inputmethod.InputMethodManager
import android.widget.*
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.util.*
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt


// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentTradeBuyOrSell.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentTradeBuyOrSell.newInstance] factory method to
 * create an instance of this fragment.
 *
 */

//  盘口行数
const val _showOrderMaxNumber = 20

class FragmentTradeBuyOrSell : BtsppFragment() {

    class OrderBookViews(val id: TextView, val price: TextView, val amount: TextView, val currentOrderdot: TextView, val bar: View, val layout: FrameLayout)
    class SimpleHistoryViews(val price: TextView, val amount: TextView, val layout: LinearLayout)

    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var listener: OnFragmentInteractionListener? = null

    private var _isbuy: Boolean = true
    lateinit var _ctx: Context
    lateinit var _view: View
    lateinit var _tradingPair: TradingPair
    private var _balanceData: JSONObject? = null
    private lateinit var _base_amount_n: BigDecimal
    private lateinit var _quote_amount_n: BigDecimal
    private var _currLimitOrders: JSONObject? = null        //  最新的盘口数据（可能不存在）
    private var _currFillOrders: JSONArray? = null          //  当前成交历史数据（可能不存在）

    private var _userOrderDataHash = LinkedHashMap<String, JSONObject>()
    //    private var _dataArrayHistory = arrayListOf<JSONObject>()
    private var _viewBidList = arrayListOf<OrderBookViews>()
    private var _viewAskList = arrayListOf<OrderBookViews>()
    private var _viewFillHistory = arrayListOf<SimpleHistoryViews>()

    private lateinit var _tf_price_watcher: UtilsDigitTextWatcher
    private lateinit var _tf_amount_watcher: UtilsDigitTextWatcher
    private lateinit var _tf_total_watcher: UtilsDigitTextWatcher

    //  ------

    lateinit var _btn_submit: Button                             // 提交按钮

//    lateinit var _layout_trade_history: LinearLayout             // 交易历史layout
//    lateinit var _layout_buy_list: LinearLayout                  // 买单列表
//    lateinit var _layout_sell_list: LinearLayout                 // 卖单列表

    lateinit var SHARED_LAYOUT_PARAMS: LinearLayout.LayoutParams // 列表左右结构的共享 layoutParams


    override fun onInitParams(args: Any?) {
        val json_array = args as JSONArray
        _isbuy = json_array.getBoolean(0)
        _tradingPair = json_array.get(1) as TradingPair
    }

    /**
     *  (public) 事件 - 处理登录成功事件
     *  更改 登录按钮为 买卖按钮
     *  获取 个人信息
     */
    fun onRefreshLoginStatus() {
        _view.findViewById<TextView>(R.id.btn_submit_core).tap {
            if (_isbuy) {
                it.text = String.format("%s%s", resources.getString(R.string.kBtnBuy), _tradingPair._quoteAsset.getString("symbol"))
            } else {
                it.text = String.format("%s%s", resources.getString(R.string.kBtnSell), _tradingPair._quoteAsset.getString("symbol"))
            }
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

        //  3、当前委托信息（过滤掉了非当前交易对的挂单）
        _userOrderDataHash.clear()
        for (order in full_account_data.getJSONArray("limit_orders").forin<JSONObject>()) {
            val sell_price = order!!.getJSONObject("sell_price")
            val base_id = sell_price.getJSONObject("base").getString("asset_id")
            val quote_id = sell_price.getJSONObject("quote").getString("asset_id")

            if (base_id == _tradingPair._baseId && quote_id == _tradingPair._quoteId) {
                //  买单：卖出 CNY
            } else if (base_id == _tradingPair._quoteId && quote_id == _tradingPair._baseId) {
                //  卖单：卖出 BTS
            } else {
                //  其他交易对的订单
                continue
            }
            _userOrderDataHash[order.getString("id")] = order
        }
    }

    /**
     * 事件 - ticker数据更新
     */
    fun onQueryTickerDataResponse(ticker_data: JSONObject) {
        if (!isAdded) {
            return
        }
        draw_ui_ticker_price_and_percent(true)
    }

    /**
     *  事件 - 成交历史数据更新
     */
    fun onQueryFillOrderHistoryResponsed(data_array: JSONArray?) {
        if (!isAdded) {
            return
        }

        if (data_array != null && data_array.length() > 0) {
            //  保存数据（Fragment重新创建时需要用到）
            _currFillOrders = data_array

            //  更新成交历史
            draw_ui_history(data_array)

            //  更新最新成交价
            draw_ui_ticker_price_and_percent(!data_array.first<JSONObject>()!!.getBoolean("issell"))
        }
    }

    /**
     *  事件 - 数据响应 - 盘口
     */
    fun onQueryOrderBookResponse(limit_orders: JSONObject) {
        if (!isAdded) {
            return
        }
        //  保存数据（Fragment重新创建时需要用到）
        val bFirst = _currLimitOrders == null
        _currLimitOrders = limit_orders
        //  更新显示精度
        _tradingPair.dynamicUpdateDisplayPrecision(limit_orders)
        //  更新输入框精度
        _tf_price_watcher.set_precision(_tradingPair._displayPrecision)
        //  刷新盘口买卖信息
        draw_ask_bid_list(limit_orders)
        //  价格输入框没有值的情况设置默认值 买界面-默认卖1价格 卖界面-默认买1价（参考huobi）
        if (bFirst) {
            val tf = _view.findViewById<EditText>(R.id.tf_price)
            val str_price = tf.text.toString()
            if (str_price == "") {
                val data = if (_isbuy) {
                    limit_orders.getJSONArray("asks").first<JSONObject>()
                } else {
                    limit_orders.getJSONArray("bids").first<JSONObject>()
                }
                if (data != null) {
                    _tf_price_watcher.set_new_text(OrgUtils.formatFloatValue(data.getString("price").toDouble(), _tradingPair._displayPrecision, false))
                    _onPriceOrAmountChanged()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            param1 = it.getString(ARG_PARAM1)
            param2 = it.getString(ARG_PARAM2)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        _view = inflater.inflate(R.layout.fragment_trade_buy_or_sell, container, false)
        _ctx = inflater.context


        refreshUI()

//        bindUIEvents()

        return _view

    }
//
//    private fun bindUIEvents() {
//        // 买入或卖出 提交事件
//        _btn_submit.setOnClickListener {
//
//        }
//
//        // 买卖数量滑动条滑动事件
//
//        // 价格输入框onChange事件
//
//        // 数量输入框onChange事件
//
//        // 交易额输入框onChange事件
//    }

    // 生成交易历史左右结构的 价格 数量 视图
    private fun createHistoryCell(): SimpleHistoryViews {
        val layout = LinearLayout(_ctx)
        layout.orientation = LinearLayout.HORIZONTAL
        layout.layoutParams = SHARED_LAYOUT_PARAMS
        layout.gravity = Gravity.CENTER_VERTICAL

        val tv_price = TextView(_ctx)
        tv_price.text = ""// OrgUtils.formatFloatValue(item.getString("price").toDouble(), _tradingPair._displayPrecision)
        tv_price.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)

        val tv_quantity = TextView(_ctx)
        tv_quantity.text = ""// OrgUtils.formatFloatValue(item.getString("amount").toDouble(), _tradingPair._numPrecision)
        tv_quantity.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv_quantity.setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
        tv_quantity.gravity = Gravity.RIGHT
        tv_quantity.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)

        layout.addView(tv_price)
        layout.addView(tv_quantity)

        return SimpleHistoryViews(tv_price, tv_quantity, layout)
    }

    // 生成买卖挂单列表的 Cell
    private fun createBuyOrSellOrderCell(index: Int, is_buy: Boolean, item: JSONObject?): OrderBookViews {
        val layout_wrap = FrameLayout(_ctx)

        val layout = LinearLayout(_ctx)
        layout.orientation = LinearLayout.HORIZONTAL
        layout.layoutParams = SHARED_LAYOUT_PARAMS
        layout.gravity = Gravity.CENTER_VERTICAL

        val tv_dot = TextView(_ctx)
        tv_dot.layoutParams = LinearLayout.LayoutParams(12.dp, LinearLayout.LayoutParams.WRAP_CONTENT)

        tv_dot.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv_dot.setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
//        if (isMyOrder){
        tv_dot.text = "●"
//        }
        tv_dot.visibility = View.INVISIBLE

        val tv_index = TextView(_ctx)
        tv_index.layoutParams = LinearLayout.LayoutParams(16.dp, LinearLayout.LayoutParams.WRAP_CONTENT)
        tv_index.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv_index.text = index.toString()
        tv_index.setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))


        val tv_price = TextView(_ctx)
        tv_price.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        tv_price.text = if (item != null) OrgUtils.formatFloatValue(item.getString("price").toDouble(), _tradingPair._displayPrecision, false) else "--"
        tv_price.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        if (is_buy) {
            tv_price.setTextColor(_ctx.resources.getColor(R.color.theme01_buyColor))
        } else {
            tv_price.setTextColor(_ctx.resources.getColor(R.color.theme01_sellColor))
        }

        val tv_quantity = TextView(_ctx)
        tv_quantity.setPadding(0, 0, 5.dp, 0)
        tv_quantity.layoutParams = LinearLayout.LayoutParams(16.dp, LinearLayout.LayoutParams.WRAP_CONTENT)
        tv_quantity.text = if (item != null) OrgUtils.formatFloatValue(item.getString("quote").toDouble(), _tradingPair._numPrecision, false) else "--"
        tv_quantity.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv_quantity.setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
        tv_quantity.gravity = Gravity.RIGHT
        tv_quantity.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)

        layout.addView(tv_dot)
        layout.addView(tv_index)
        layout.addView(tv_price)
        layout.addView(tv_quantity)


        val layout_view_block = LinearLayout(_ctx)
        layout_view_block.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 26.dp).apply {
            gravity = Gravity.RIGHT
        }
        layout_view_block.gravity = Gravity.RIGHT
        val view_block = View(_ctx)
        view_block.layoutParams = LinearLayout.LayoutParams((index * 5).dp, 26.dp).apply {
            gravity = Gravity.RIGHT
        }
        if (is_buy) {
            view_block.setBackgroundColor(_ctx.resources.getColor(R.color.theme01_buyColor))
        } else {
            view_block.setBackgroundColor(_ctx.resources.getColor(R.color.theme01_sellColor))
        }
        view_block.background.alpha = 50
        view_block.visibility = View.INVISIBLE

        layout_view_block.addView(view_block)
        layout_wrap.addView(layout_view_block)
        layout_wrap.addView(layout)

        return OrderBookViews(tv_index, tv_price, tv_quantity, tv_dot, view_block, layout_wrap)
    }

    /**
     *  (private) 事件 - 百分比按钮点击
     */
    private fun onPercentButtonClicked(n_percent: BigDecimal) {
        if (_balanceData == null) {
            showToast(resources.getString(R.string.kVcTradeTipPleaseLoginFirst))
//            _gotoLogin()
            return
        }

        //  保留小数位数 向下取整
        val n_value_of_percent = if (_isbuy) {
            _base_amount_n.multiply(n_percent).setScale(_tradingPair._basePrecision, BigDecimal.ROUND_DOWN)
        } else {
            _quote_amount_n.multiply(n_percent).setScale(_tradingPair._quotePrecision, BigDecimal.ROUND_DOWN)
        }

        if (_isbuy) {
            //  更新总金额
            _tf_total_watcher.set_new_text(n_value_of_percent.toString())
            _onTfTotalChanged(_tf_total_watcher.get_tf_string())
        } else {
            //  更新数量
            _tf_amount_watcher.set_new_text(n_value_of_percent.toString())
            _onPriceOrAmountChanged()
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
            _tf_total_watcher.set_new_text(OrgUtils.formatFloatValue(n_total.toDouble(), _tradingPair._basePrecision, false))
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

    private fun draw_ui_history(data_array: JSONArray) {
        for ((idx, v) in _viewFillHistory.withIndex()) {
            val data = data_array.optJSONObject(idx)
            if (data != null) {
                v.price.text = OrgUtils.formatFloatValue(data.getString("price").toDouble(), _tradingPair._displayPrecision)
                v.amount.text = OrgUtils.formatFloatValue(data.getString("amount").toDouble(), _tradingPair._numPrecision)
                //  设置颜色
                if (data.optBoolean("iscall")) {
                    v.amount.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                    v.price.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                } else {
                    v.amount.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    if (data.getBoolean("issell")) {
                        v.price.setTextColor(resources.getColor(R.color.theme01_sellColor))
                    } else {
                        v.price.setTextColor(resources.getColor(R.color.theme01_buyColor))
                    }
                }
            } else {
                break
            }
        }
    }

    private fun init_fill_history_view() {
        _view.findViewById<LinearLayout>(R.id.layout_history_list).let { layout ->
            layout.removeAllViews()
            _viewFillHistory.clear()
            for (i in 0 until _showOrderMaxNumber) {
                val item = createHistoryCell()
                _viewFillHistory.add(item)
                layout.addView(item.layout)
            }
        }
        _currFillOrders?.let { draw_ui_history(it) }
    }

    private fun init_order_book() {
        val layout_bid_list: LinearLayout = _view.findViewById(R.id.layout_bid_list)
        val layout_ask_list: LinearLayout = _view.findViewById(R.id.layout_ask_list)
        layout_bid_list.removeAllViews()
        layout_ask_list.removeAllViews()
        _viewBidList.clear()
        _viewAskList.clear()
        for (i in 0 until _showOrderMaxNumber) {
            val item = createBuyOrSellOrderCell(i + 1, true, null)
            layout_bid_list.addView(item.layout)
            _viewBidList.add(item)
        }
        for (i in 0 until _showOrderMaxNumber) {
            val item = createBuyOrSellOrderCell(_showOrderMaxNumber - i, false, null)
            layout_ask_list.addView(item.layout)
            _viewAskList.add(item)
        }
        //  已有数据：直接刷新
        _currLimitOrders?.let { draw_ask_bid_list(it) }
    }

    private fun draw_ask_bid_core(viewList: ArrayList<OrderBookViews>, dataList: JSONArray, half_width: Int, maxQuoteValue: Double, isask: Boolean) {
        viewList.forEachIndexed { index, orderBookViews ->
            //  REMARK：卖盘，数据倒序显示。
            val order = if (isask) dataList.optJSONObject(_showOrderMaxNumber - index - 1) else dataList.optJSONObject(index)
            if (order != null) {
                if (order.optBoolean("iscall")) {
                    orderBookViews.id.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                    orderBookViews.amount.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                    orderBookViews.price.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                    orderBookViews.currentOrderdot.visibility = View.INVISIBLE
                } else {
                    orderBookViews.id.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    orderBookViews.amount.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    val color = if (isask) R.color.theme01_sellColor else R.color.theme01_buyColor
                    orderBookViews.price.setTextColor(resources.getColor(color))
                    if (_userOrderDataHash.containsKey(order.getString("oid"))) {
                        orderBookViews.currentOrderdot.visibility = View.VISIBLE
                        orderBookViews.currentOrderdot.setTextColor(resources.getColor(color))
                    } else {
                        orderBookViews.currentOrderdot.visibility = View.INVISIBLE
                    }
                }
                orderBookViews.amount.text = OrgUtils.formatFloatValue(order.getString("quote").toDouble(), _tradingPair._numPrecision, false)
                orderBookViews.price.text = OrgUtils.formatFloatValue(order.getString("price").toDouble(), _tradingPair._displayPrecision, false)
                //  买盘 背景
                orderBookViews.bar.visibility = View.VISIBLE
                orderBookViews.bar.layoutParams = LinearLayout.LayoutParams(max(min(order.getDouble("quote") * half_width / maxQuoteValue, half_width.toDouble()), 1.0).roundToInt(), 26.dp).apply {
                    gravity = Gravity.RIGHT
                }
                //  点击事件
                orderBookViews.layout.setOnClickListener { onOrderBookCellClicked(order) }
            } else {
                orderBookViews.price.text = "--"
                orderBookViews.amount.text = "--"
                orderBookViews.bar.visibility = View.INVISIBLE
                orderBookViews.layout.setOnClickListener(null)
            }
        }
    }

    /**
     *  （private) 盘口CELL点击
     */
    private fun onOrderBookCellClicked(order: JSONObject) {
        _tf_price_watcher.set_new_text(OrgUtils.formatFloatValue(order.getString("price").toDouble(), _tradingPair._displayPrecision, false))
        _onPriceOrAmountChanged()
    }

    private fun draw_ask_bid_list(data: JSONObject) {
        val bids = data.getJSONArray("bids")
        val asks = data.getJSONArray("asks")

        //  更新最大交易量的挂单
        var _fMaxQuoteValue = 0.0
        var idx = 0
        for (item in bids.forin<JSONObject>()) {
            val value = item!!.getString("quote").toDouble()
            if (_fMaxQuoteValue < value) {
                _fMaxQuoteValue = value
            }
            ++idx
            if (idx >= _showOrderMaxNumber) {
                break
            }
        }
        idx = 0
        for (item in asks.forin<JSONObject>()) {
            val value = item!!.getString("quote").toDouble()
            if (_fMaxQuoteValue < value) {
                _fMaxQuoteValue = value
            }
            ++idx
            if (idx >= _showOrderMaxNumber) {
                break
            }
        }

        val half_width = (Utils.screen_width / 2).toInt()

        draw_ask_bid_core(_viewBidList, bids, half_width, _fMaxQuoteValue, isask = false)
        draw_ask_bid_core(_viewAskList, asks, half_width, _fMaxQuoteValue, isask = true)
    }

    private fun refreshUI() {
        val base_symbol = _tradingPair._baseAsset.getString("symbol")
        val quote_symbol = _tradingPair._quoteAsset.getString("symbol")

        //  配置公共 LayoutParams
        SHARED_LAYOUT_PARAMS = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(26f))
        SHARED_LAYOUT_PARAMS.gravity = Gravity.CENTER_VERTICAL

        //  配置滑动条颜色和图标
        val seek_color = if (_isbuy) {
            R.color.theme01_buyColor
        } else {
            R.color.theme01_sellColor
        }

        // REMARK seekbar 已经删除了
//        _view.findViewById<SeekBar>(R.id.id_slider_amount_percent).let { seek ->
//            seek.progressDrawable.setColorFilter(resources.getColor(seek_color), PorterDuff.Mode.SRC_ATOP)
//        }

        // 计算右侧列表ScrollView高度
        calcOrderScrollViewHeight()

        //  第一排涨跌文字
        draw_ui_ticker_price_and_percent(true)

        //  输入框标题栏
        _view.findViewById<TextView>(R.id.tf_price_title).text = String.format(resources.getString(R.string.kVcVerTradeLabelPrice), base_symbol)
        _view.findViewById<TextView>(R.id.tf_amount_title).text = String.format(resources.getString(R.string.kVcVerTradeLabelAmount), quote_symbol)
        _view.findViewById<TextView>(R.id.tf_total_title).text = String.format(resources.getString(R.string.kVcVerTradeLabelTotal), base_symbol)

        //  输入框占位符
        val tf_price = _view.findViewById<EditText>(R.id.tf_price)
        val tf_amount = _view.findViewById<EditText>(R.id.tf_amount)
        val tf_total = _view.findViewById<EditText>(R.id.tf_total)
        if (_isbuy) {
            tf_price.hint = resources.getString(R.string.kPlaceHolderBuyPrice)
            tf_amount.hint = resources.getString(R.string.kPlaceHolderBuyAmount)
        } else {
            tf_price.hint = resources.getString(R.string.kPlaceHolderSellPrice)
            tf_amount.hint = resources.getString(R.string.kPlaceHolderSellAmount)
        }

        //  输入框输入事件监听
        _tf_price_watcher = UtilsDigitTextWatcher().set_tf(tf_price).set_precision(_tradingPair._displayPrecision)
        tf_price.addTextChangedListener(_tf_price_watcher)
        _tf_price_watcher.on_value_changed(::_onTfPriceChanged)

        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(tf_amount).set_precision(_tradingPair._quotePrecision)
        tf_amount.addTextChangedListener(_tf_amount_watcher)
        _tf_amount_watcher.on_value_changed(::_onTfAmountChanged)

        _tf_total_watcher = UtilsDigitTextWatcher().set_tf(tf_total).set_precision(_tradingPair._basePrecision)
        tf_total.addTextChangedListener(_tf_total_watcher)
        _tf_total_watcher.on_value_changed(::_onTfTotalChanged)

        //  REMARK：重写数量输入框的touch事件，尚未登录的清空下，不弹出键盘（直接消耗掉事件)。
//        tf_price.setOnTouchListener { _, event -> return@setOnTouchListener _processTouchEvents(event) }
        tf_amount.setOnTouchListener { _, event -> return@setOnTouchListener _processTouchEvents(event) }
        tf_total.setOnTouchListener { _, event -> return@setOnTouchListener _processTouchEvents(event) }

        //  可用
        _draw_ui_available(null, true, _isbuy)
        _draw_market_fee(if (_isbuy) _tradingPair._quoteAsset else _tradingPair._baseAsset)

        //  登录 or 买入 or 卖出
        val _confirmation_btn_of_buy = _view.findViewById<Button>(R.id.btn_submit_core)
        if (WalletManager.sharedWalletManager().isWalletExist()) {
            if (_isbuy) {
                _confirmation_btn_of_buy.text = String.format("%s%s", resources.getString(R.string.kBtnBuy), quote_symbol)
            } else {
                _confirmation_btn_of_buy.text = String.format("%s%s", resources.getString(R.string.kBtnSell), quote_symbol)
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

        //  百分比按钮
        _view.findViewById<Button>(R.id.button_percent25).setOnClickListener { onPercentButtonClicked(BigDecimal.valueOf(0.25)) }
        _view.findViewById<Button>(R.id.button_percent50).setOnClickListener { onPercentButtonClicked(BigDecimal.valueOf(0.5)) }
        _view.findViewById<Button>(R.id.button_percent75).setOnClickListener { onPercentButtonClicked(BigDecimal.valueOf(0.75)) }
        _view.findViewById<Button>(R.id.button_percent100).setOnClickListener { onPercentButtonClicked(BigDecimal.ONE) }

        //  初始化UI - 盘口
        init_order_book()

        //  初始化UI - 成交历史
        init_fill_history_view()

        //  REMARK：延迟滚动到最底部
        Utils.delay { _view.findViewById<ScrollView>(R.id.sv_ask_listview).fullScroll(ScrollView.FOCUS_DOWN) }
    }

    private fun _processTouchEvents(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_DOWN) {
            if (_balanceData == null) {
                showToast(resources.getString(R.string.kVcTradeTipPleaseLoginFirst))
                endInput()
                return true
            }
        }
        return false
    }

    /**
     *  关闭键盘
     */
    private fun endInput() {
        _tf_price_watcher.endInput()
        _tf_amount_watcher.endInput()
        _tf_total_watcher.endInput()
        val imm = activity?.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.let {
            it.hideSoftInputFromWindow(_view.findViewById<EditText>(R.id.tf_price).windowToken, 0)
            it.hideSoftInputFromWindow(_view.findViewById<EditText>(R.id.tf_amount).windowToken, 0)
            it.hideSoftInputFromWindow(_view.findViewById<EditText>(R.id.tf_total).windowToken, 0)
            return@let
        }
    }

    private fun _draw_market_fee(asset: JSONObject, account: JSONObject? = null) {
        val market_fee_percent = asset.optJSONObject("options")?.optString("market_fee_percent", null)
        if (market_fee_percent != null) {
            val n_market_fee_percent = bigDecimalfromAmount(market_fee_percent, BigDecimal.valueOf(10.0.pow(2)))
            _view.findViewById<TextView>(R.id.label_txt_market_fee).text = String.format("%s%%", n_market_fee_percent.toPlainString())
        } else {
            _view.findViewById<TextView>(R.id.label_txt_market_fee).text = "0%"
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
            it.text = value_str
            it.setTextColor(resources.getColor(value_color))
        }
    }

    /**
     * 刷新价格和百分比信息
     */
    private fun draw_ui_ticker_price_and_percent(isbuy: Boolean) {
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
            label_txt_curr_price_percent.text = "+$percent%"
            label_txt_curr_price_percent.setTextColor(resources.getColor(R.color.theme01_buyColor))
        } else if (percent_value < 0) {
            label_txt_curr_price_percent.text = "$percent%"
            label_txt_curr_price_percent.setTextColor(resources.getColor(R.color.theme01_sellColor))
        } else {
            label_txt_curr_price_percent.text = "$percent%"
            label_txt_curr_price_percent.setTextColor(resources.getColor(R.color.theme01_zeroColor))
        }
    }

    private fun _gotoLogin() {
        if (WalletManager.sharedWalletManager().isWalletExist()) {
            return
        }
        activity!!.goTo(ActivityLogin::class.java, true)
    }

    private fun onSubmitClicked() {
        if (WalletManager.sharedWalletManager().isWalletExist()) {
            onBuyOrSellActionClicked()
        } else {
            _gotoLogin()
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
                    if (new_order_id != null && _userOrderDataHash.containsKey(new_order_id)) {
                        new_order = _userOrderDataHash[new_order_id]
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

    private fun calcOrderScrollViewHeight() {
        // 左边固定区域(用于计算历史订单view的高度)
        val scale = _ctx.resources.getDisplayMetrics().density
        val dm = DisplayMetrics()
        activity!!.windowManager.defaultDisplay.getMetrics(dm)
        val pix_height = dm.heightPixels.toFloat()

        // 状态栏(需计算) 标题栏(40px) tab(40px) 价格百分比(48px) 总margin(25dp + 20dp + 26dp = 71dp)
        val right_scroll_height_pix = ((pix_height - (40 + 40 + 48 + 71) * scale) / 2).toInt()
        val right_scroll_height_dp = (right_scroll_height_pix / scale)

        val sv_sell_list = _view.findViewById<ScrollView>(R.id.sv_ask_listview)
        val layout_params_sell_list = sv_sell_list.layoutParams
        layout_params_sell_list.height = right_scroll_height_dp.dp.toInt()
        sv_sell_list.layoutParams = layout_params_sell_list
    }

    fun getStatusBarHeight(context: Context): Int {
        val resources = context.resources
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return resources.getDimensionPixelSize(resourceId)
    }

    // TODO: Rename method, update argument and hook method into UI event
    fun onButtonPressed(uri: Uri) {
        listener?.onFragmentInteraction(uri)
    }

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

    companion object {
        /**
         * Use this factory method to create a new instance of
         * this fragment using the provided parameters.
         *
         * @param param1 Parameter 1.
         * @param param2 Parameter 2.
         * @return A new instance of fragment FragmentTradeBuyOrSell.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentTradeBuyOrSell().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
