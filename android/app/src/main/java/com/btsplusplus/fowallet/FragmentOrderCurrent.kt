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
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentOrderCurrent.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentOrderCurrent.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentOrderCurrent : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _ctx: Context? = null
    private var _view: View? = null
    private var _dataArray = mutableListOf<JSONObject>()
    lateinit var _full_account_data: JSONObject
    private var _tradingPair: TradingPair? = null

    override fun onInitParams(args: Any?) {
        val full_account_data = args as JSONObject
        refreshWithFullUserData(full_account_data)
    }

    /**
     *  (private) 刷新数据
     */
    private fun refreshWithFullUserData(full_account_data: JSONObject) {
        _full_account_data = full_account_data
        genCurrentLimitOrderData(full_account_data.getJSONArray("limit_orders"))
    }

    /**
     * 当前订单：生成当前订单列表信息
     */
    private fun genCurrentLimitOrderData(limit_orders: JSONArray) {
        _dataArray.clear()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val assetBasePriority = chainMgr.genAssetBasePriorityHash()
        for (order in limit_orders) {
            val sell_price = order!!.getJSONObject("sell_price")
            val base = sell_price.getJSONObject("base")
            val quote = sell_price.getJSONObject("quote")
            val base_asset = chainMgr.getChainObjectByID(base.getString("asset_id"))
            val quote_asset = chainMgr.getChainObjectByID(quote.getString("asset_id"))
            val base_priority = assetBasePriority.optInt(base_asset.getString("symbol"), 0)
            val quote_priority = assetBasePriority.optInt(quote_asset.getString("symbol"), 0)
            val base_precision = base_asset.getInt("precision")
            val quote_precision = quote_asset.getInt("precision")
            val base_value = OrgUtils.calcAssetRealPrice(base.getString("amount"), base_precision)
            val quote_value = OrgUtils.calcAssetRealPrice(quote.getString("amount"), quote_precision)

            //  REMARK: base 是卖出的资产，除以 base 则为卖价(每1个 base 资产的价格)。反正 base / quote 则为买入价。
            var issell: Boolean
            var price: Double
            var price_str: String
            var amount_str: String
            var total_str: String
            var base_sym: String
            var quote_sym: String
            if (base_priority > quote_priority) {
                //  buy     price = base / quote
                issell = false
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
                issell = true
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
            _dataArray.add(data_item)
        }
        //  按照ID降序
        _dataArray.sortByDescending { it.getString("id") }
    }

    private fun refreshUI() {
        if (_view == null) {
            return
        }
        val container: LinearLayout = _view!!.findViewById(R.id.layout_my_order_current_from_my_fragment)
        container.removeAllViews()

        if (_dataArray.size > 0) {
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
            layout_params.gravity = Gravity.CENTER_VERTICAL
            for (item in _dataArray) {
                createCell(_ctx!!, layout_params, container, item)
            }
        } else {
            container.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, _ctx!!.resources.getString(R.string.kVcOrderTipNoOpenOrder)))
        }
    }

    private fun createCell(ctx: Context, layout_params: LinearLayout.LayoutParams, ly: LinearLayout, data: JSONObject) {
        val ly_wrap: LinearLayout = LinearLayout(ctx)
        ly_wrap.orientation = LinearLayout.VERTICAL


        // layout1 左: Buy SEED/CNY 右: 07-11 11:50
        val ly1 = LinearLayout(ctx)
        ly1.orientation = LinearLayout.HORIZONTAL
        ly1.layoutParams = layout_params
        ly1.setPadding(0, 5.dp, 0, 0)

        val tv1 = TextView(ctx)
        if (data.getBoolean("issell")) {
            tv1.text = ctx.resources.getString(R.string.kBtnSell)
            tv1.setTextColor(resources.getColor(R.color.theme01_sellColor))
        } else {
            tv1.text = ctx.resources.getString(R.string.kBtnBuy)
            tv1.setTextColor(resources.getColor(R.color.theme01_buyColor))
        }
        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        tv1.gravity = Gravity.CENTER_VERTICAL

        val tv2 = TextView(ctx)
        val quote_symbol = data.getString("quote_symbol")
        val base_symbol = data.getString("base_symbol")
        tv2.text = "${quote_symbol}/${base_symbol}"
        tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        tv2.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv2.gravity = Gravity.CENTER_VERTICAL
        tv2.setPadding(5.dp, 0, 0, 0)

        val layout_of_left = LinearLayout(ctx)
        layout_of_left.layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        layout_of_left.addView(tv1)
        layout_of_left.addView(tv2)
        layout_of_left.gravity = Gravity.CENTER_VERTICAL

        var time = Utils.fmtLimitOrderTimeShowString(data.getString("time"))
        val tv3 = TextView(ctx)
        tv3.text = String.format(R.string.kVcOrderExpired.xmlstring(ctx), time)
        tv3.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv3.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv3.gravity = Gravity.CENTER
        var layout_tv3 = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        layout_tv3.gravity = Gravity.CENTER_VERTICAL
        tv3.layoutParams = layout_tv3

        val tv_cancel = ViewUtils.createTextView(ctx, ctx.resources.getString(R.string.kVcOrderBtnCancel), 11.0f, R.color.theme01_color03, false)
        tv_cancel.gravity = Gravity.RIGHT
        val layout_cancel = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        layout_cancel.gravity = Gravity.CENTER_VERTICAL
        tv_cancel.layoutParams = layout_cancel

        // layout2 左: price(CNY) 中 Amount(SEED) 右 总金额(CNY)
        val ly2: LinearLayout = LinearLayout(ctx)
        ly2.orientation = LinearLayout.HORIZONTAL
        ly2.layoutParams = layout_params

        val tv4 = TextView(ctx)
        tv4.text = "${R.string.kLabelTradeHisTitlePrice.xmlstring(ctx)}(${base_symbol})"
        tv4.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv4.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv4.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
        tv4.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.LEFT)

        val tv5 = TextView(ctx)
        tv5.text = "${R.string.kLableBidAmount.xmlstring(ctx)}(${quote_symbol})"
        tv5.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv5.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv5.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
        tv5.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.CENTER)

        val tv6 = TextView(ctx)
        tv6.text = "${R.string.kVcOrderTotal.xmlstring(ctx)}(${base_symbol})"
        tv6.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv6.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv6.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        tv6.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.RIGHT)

        // layout3
        val ly3: LinearLayout = LinearLayout(ctx)
        ly3.orientation = LinearLayout.HORIZONTAL
        ly3.layoutParams = layout_params

        val tv7 = TextView(ctx)
        tv7.text = data.getString("price")
        tv7.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv7.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv7.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
        tv7.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.LEFT)

        val tv8 = TextView(ctx)
        tv8.text = data.getString("amount")
        tv8.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv8.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv8.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
        tv8.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.CENTER)

        val tv9 = TextView(ctx)
        tv9.text = data.getString("total")
        tv9.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv9.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv9.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        tv9.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.RIGHT)

        // 线
        val lv_line = View(ctx)
        var layout_tv9 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp)
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = layout_tv9

        ly1.addView(layout_of_left)
        ly1.addView(tv3)
        ly1.addView(tv_cancel)

        ly2.addView(tv4)
        ly2.addView(tv5)
        ly2.addView(tv6)

        ly3.addView(tv7)
        ly3.addView(tv8)
        ly3.addView(tv9)


        ly_wrap.addView(ly1)
        ly_wrap.addView(ly2)
        ly_wrap.addView(ly3)
        ly_wrap.addView(lv_line)

        ly.addView(ly_wrap)

        //  设置当前订单号到按钮上
        tv_cancel.tag = data.getString("id")
        tv_cancel.setOnClickListener { v: View ->
            onButtonClicked_CancelOrder(data)
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

        //  计算手续费对象
        val fee_item = ChainObjectManager.sharedChainObjectManager().getFeeItem(EBitsharesOperations.ebo_limit_order_cancel, _full_account_data, extra_balance = extra_balance)
        if (!fee_item.getBoolean("sufficient")) {
            showToast(_ctx!!.resources.getString(R.string.kTipsTxFeeNotEnough))
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
        val account_data = _full_account_data.getJSONObject("account")
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
                //  订单取消了：设置待更新标记
                if (_tradingPair != null) {
                    ScheduleManager.sharedScheduleManager().sub_market_monitor_order_update(_tradingPair!!, true)
                    //  设置订单变化标记
                    TempManager.sharedTempManager().userLimitOrderDirty = true
                }
                ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_id).then {
                    mask.dismiss()
                    refreshWithFullUserData(it as JSONObject)
                    refreshUI()
                    showToast(String.format(_ctx!!.resources.getString(R.string.kVcOrderTipTxCancelFullOK), order_id))
                    //  [统计]
                    btsppLogCustom("txCancelLimitOrderFullOK", jsonObjectfromKVS("account", account_id))
                    return@then null
                }.catch {
                    mask.dismiss()
                    showToast(String.format(_ctx!!.resources.getString(R.string.kVcOrderTipTxCancelOK), order_id))
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

    private fun createLayout(gr: Int): LinearLayout.LayoutParams {
        val layout = LinearLayout.LayoutParams(0.dp, 24.dp, 1.0f)
        layout.gravity = gr
        return layout
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_order_current, container, false)
        //  刷新界面
        refreshUI()
        return _view
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
}
