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
    private var _from: String? = null

    override fun onInitParams(args: Any?) {
        val _args = args as JSONObject
        val tradeHistory = _args.getJSONArray("data")
        _from = _args.getString("from")
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
        _dataArray.sortByDescending { it.getString("id").split(".").last().toInt() }
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
                // createCell(_ctx!!, layout_params, container, item)
                container.addView(ViewOrderCell(_ctx!!,item,_from!!))
            }
        } else {
            val string_no_data = if (_from == "settlement_orders") {"没有任何清算单"} else {resources.getString(R.string.kVcOrderTipNoHistory)}

            container.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, string_no_data))
        }
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
