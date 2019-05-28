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
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentOrderHistory.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentOrderHistory.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentOrderHistory : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _ctx: Context? = null
    private var _view: View? = null
    private var _dataArray = mutableListOf<JSONObject>()

    override fun onInitParams(args: Any?) {
        val tradeHistory = args as JSONArray
        genTradeHistoryData(tradeHistory)
        //  查询历史交易的时间戳信息
        if (_dataArray.size > 0) {
            val block_num_hash = JSONObject()
            _dataArray.forEach {
                block_num_hash.put(it.getString("block_num"), true)
            }
            ChainObjectManager.sharedChainObjectManager().queryAllBlockHeaderInfos(block_num_hash.keys().toJSONArray(), false).then {
                _onQueryAllBlockHeaderInfosResponsed()
                return@then null
            }.catch {
            }
        }
    }

    /**
     * (private) 处理查询区块头信息返回结果
     */
    private fun _onQueryAllBlockHeaderInfosResponsed() {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        _dataArray.forEach {
            val block_num = it.getString("block_num")
            val block_header = chainMgr.getBlockHeaderInfoByBlockNumber(block_num)
            it.put("block_time", block_header?.getString("timestamp") ?: "")
        }
        //  刷新界面
        refreshUI()
    }

    /**
     *  历史订单：生成历史订单列表信息
     */
    private fun genTradeHistoryData(history_list: JSONArray) {
        _dataArray.clear()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val assetBasePriority = chainMgr.genAssetBasePriorityHash()
        for (history in history_list) {
            val fill_info = history!!.getJSONArray("op").getJSONObject(1)
            val pays = fill_info.getJSONObject("pays")
            val receives = fill_info.getJSONObject("receives")
            //  是否是爆仓单
            val order_id = fill_info.getString("order_id")
            val isCallOrder = order_id.split(".")[1].toInt() == EBitsharesObjectType.ebot_call_order.value

            val pays_asset = chainMgr.getChainObjectByID(pays.getString("asset_id"))
            val receives_asset = chainMgr.getChainObjectByID(receives.getString("asset_id"))

            val pays_priority = assetBasePriority.optInt(pays_asset.getString("symbol"), 0)
            val receives_priority = assetBasePriority.optInt(receives_asset.getString("symbol"), 0)

            val pays_precision = pays_asset.getInt("precision")
            val receives_precision = receives_asset.getInt("precision")

            val pays_value = OrgUtils.calcAssetRealPrice(pays.getString("amount"), pays_precision)
            val receives_value = OrgUtils.calcAssetRealPrice(receives.getString("amount"), receives_precision)

            //  REMARK: pays 是卖出的资产，除以 pays 则为卖价(每1个 pays 资产的价格)。反正 pays / receives 则为买入价。
            var issell: Boolean
            var price: Double
            var price_str: String
            var amount_str: String
            var total_str: String
            var pays_sym: String
            var receives_sym: String
            if (pays_priority > receives_priority) {
                //  buy     price = pays / receives
                issell = false
                price = pays_value / receives_value
                price_str = OrgUtils.formatFloatValue(price, pays_precision)

                amount_str = OrgUtils.formatAssetString(receives.getString("amount"), receives_precision)
                total_str = OrgUtils.formatAssetString(pays.getString("amount"), pays_precision)

                pays_sym = pays_asset.getString("symbol")
                receives_sym = receives_asset.getString("symbol")
            } else {
                //  sell    price = receives / pays
                issell = true
                price = receives_value / pays_value
                price_str = OrgUtils.formatFloatValue(price, receives_precision)

                amount_str = OrgUtils.formatAssetString(pays.getString("amount"), pays_precision)
                total_str = OrgUtils.formatAssetString(receives.getString("amount"), receives_precision)

                pays_sym = receives_asset.getString("symbol")
                receives_sym = pays_asset.getString("symbol")
            }
            //  REMARK：特殊处理，如果按照 pays or receives 的精度格式化出价格为0了，则扩大精度重新格式化。
            if (price_str == "0") {
                price_str = OrgUtils.formatFloatValue(price, 8)
            }
            //  构造可变对象，方便后面更新 block_time 字段。
            val data_item = jsonObjectfromKVS("ishistory", true, "issell", issell, "price", price_str,
                    "amount", amount_str, "total", total_str, "base_symbol", pays_sym, "quote_symbol", receives_sym,
                    "id", history.getString("id"), "block_num", history.getString("block_num"),
                    "seller", fill_info.getString("account_id"), "iscall", isCallOrder)
            _dataArray.add(data_item)
        }
        //  按照ID降序
        _dataArray.sortByDescending { it.getString("id") }
    }

    private fun refreshUI() {
        if (_view == null) {
            return
        }
        if (this.activity == null) {
            return
        }
        val container: LinearLayout = _view!!.findViewById(R.id.layout_my_order_history_from_my_fragment)
        container.removeAllViews()

        if (_dataArray.size > 0) {
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(24f))
            layout_params.gravity = Gravity.CENTER_VERTICAL
            for (item in _dataArray) {
                createCell(_ctx!!, layout_params, container, item)
            }
        } else {
            container.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, resources.getString(R.string.kVcOrderTipNoHistory)))
        }
    }

    private fun createLayout(gr: Int): LinearLayout.LayoutParams {
        var layout_tv3 = LinearLayout.LayoutParams(toDp(0f), toDp(24.0f))
        layout_tv3.weight = 1.0f
        layout_tv3.gravity = gr
        return layout_tv3
    }

    private fun createCell(ctx: Context, layout_params: LinearLayout.LayoutParams, ly: LinearLayout, data: JSONObject) {
        val ly_wrap: LinearLayout = LinearLayout(ctx)
        ly_wrap.orientation = LinearLayout.VERTICAL

        // layout1 左: Buy SEED/CNY 右: 07-11 11:50
        val ly1: LinearLayout = LinearLayout(ctx)
        ly1.orientation = LinearLayout.HORIZONTAL
        ly1.layoutParams = layout_params
        ly1.setPadding(0, toDp(5.0f), 0, 0)
        val tv1 = TextView(ctx)
        if (data.getBoolean("issell")) {
            tv1.text = ctx.resources.getString(R.string.kBtnSell)
            if (data.getBoolean("iscall")) {
                tv1.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
            } else {
                tv1.setTextColor(resources.getColor(R.color.theme01_sellColor))
            }
        } else {
            tv1.text = ctx.resources.getString(R.string.kBtnBuy)
            if (data.getBoolean("iscall")) {
                tv1.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
            } else {
                tv1.setTextColor(resources.getColor(R.color.theme01_buyColor))
            }
        }
        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv1.gravity = Gravity.CENTER_VERTICAL

        val tv2 = TextView(ctx)
        val quote_symbol = data.getString("quote_symbol")
        val base_symbol = data.getString("base_symbol")
        tv2.text = "${quote_symbol}/${base_symbol}"
        tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        tv2.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv2.gravity = Gravity.CENTER_VERTICAL
        tv2.setPadding(toDp(5.0f), 0, 0, 0)

        val tv3 = TextView(ctx)
        val block_time = data.optString("block_time", "")
        if (block_time == "") {
            tv3.visibility = android.view.View.INVISIBLE
        } else {
            tv3.visibility = android.view.View.VISIBLE
            tv3.text = Utils.fmtAccountHistoryTimeShowString(block_time)
        }
        tv3.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10.0f)
        tv3.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv3.gravity = Gravity.BOTTOM or Gravity.RIGHT
        var layout_tv3 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_tv3.weight = 1.0f
        layout_tv3.gravity = Gravity.RIGHT or Gravity.BOTTOM
        tv3.layoutParams = layout_tv3


        // layout2 左: price(CNY) 中 Amount(SEED) 右 总金额(CNY)
        val ly2: LinearLayout = LinearLayout(ctx)
        ly2.orientation = LinearLayout.HORIZONTAL
        ly2.layoutParams = layout_params

        val tv4 = TextView(ctx)
        tv4.text = "${R.string.kLableBidPrice.xmlstring(ctx)}(${base_symbol})"
        tv4.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv4.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv4.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
        tv4.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.LEFT)

        val tv5 = TextView(ctx)
        tv5.text = "${R.string.kLabelTradeHisTitleAmount.xmlstring(ctx)}(${quote_symbol})"
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
        var layout_tv9 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(1.0f))
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = layout_tv9

        ly1.addView(tv1)
        ly1.addView(tv2)
        ly1.addView(tv3)

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
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_order_history, container, false)
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
