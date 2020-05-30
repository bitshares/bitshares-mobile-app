package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.btsplusplus.fowallet.utils.ModelUtils
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

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
    private var _isSettlementsOrder = false

    override fun onInitParams(args: Any?) {
        val _args = args as JSONObject
        if (_args.has("isSettlementsOrder") && _args.getBoolean("isSettlementsOrder")) {
            //  init for settlements orders
            _isSettlementsOrder = true
        } else {
            val tradeHistory = _args.getJSONArray("data")
            genTradeHistoryData(tradeHistory)
            //  查询历史交易的时间戳信息
            if (_dataArray.size > 0) {
                val block_num_hash = JSONObject()
                _dataArray.forEach {
                    block_num_hash.put(it.getString("block_num"), true)
                }
                ChainObjectManager.sharedChainObjectManager().queryAllBlockHeaderInfos(block_num_hash.keys().toJSONArray(),
                        false).then {
                    _onQueryAllBlockHeaderInfosResponsed()
                    return@then null
                }.catch {
                }
            }
        }
    }

    /**
     *  (public) 查询清算单
     */
    fun querySettlementOrders(tradingPair: TradingPair? = null, full_account_data: JSONObject? = null) {
        waitingOnCreateView().then {
            _querySettlementOrdersCore(tradingPair, full_account_data)
        }
    }

    private fun _querySettlementOrdersCore(tradingPair: TradingPair?, full_account_data: JSONObject?) {
        if (!_isSettlementsOrder) {
            return
        }
        activity?.let { ctx ->
            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx).apply { show() }
            //  TODO:4.0 limit number?
            val p1 = if (tradingPair != null) {
                chainMgr.querySettlementOrders(tradingPair._smartAssetId, 100)
            } else {
                chainMgr.querySettlementOrdersByAccount(full_account_data!!.getJSONObject("account").getString("name"), 100)
            }
            p1.then {
                val data_array = it as? JSONArray
                //  查询依赖
                val ids = JSONObject()
                if (data_array != null && data_array.length() > 0) {
                    for (item in data_array.forin<JSONObject>()) {
                        ids.put(item!!.getJSONObject("balance").getString("asset_id"), true)
                        ids.put(item.getString("owner"), true)
                    }
                }
                val ids01_array = ids.keys().toJSONArray()
                return@then chainMgr.queryAllGrapheneObjects(ids01_array).then {
                    //  查询智能资产信息
                    val ids02_array = ModelUtils.collectDependence(ids01_array, jsonArrayfrom("bitasset_data_id"))
                    return@then chainMgr.queryAllGrapheneObjectsSkipCache(ids02_array).then {
                        //  查询背书资产信息
                        val ids03_array = ModelUtils.collectDependence(ids02_array, jsonArrayfrom("options", "short_backing_asset"))
                        return@then chainMgr.queryAllGrapheneObjects(ids03_array).then {
                            //  异步计算订单数据
                            BtsppAsyncTask().run {
                                onGenerateSettlementorders(data_array, tradingPair)
                            }.then {
                                //  刷新显示
                                refreshUI()
                                mask.dismiss()
                            }
                            return@then null
                        }
                    }
                }
            }.catch {
                mask.dismiss()
                ctx.showToast(R.string.tip_network_error.xmlstring(ctx))
            }
            return@let
        }
    }

    /**
     *  (private) 生成订单数据
     */
    private fun onGenerateSettlementorders(data_array: JSONArray?, tradingPair: TradingPair?) {
        _dataArray.clear()

        if (data_array != null && data_array.length() > 0) {
            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            for (settle_order in data_array.forin<JSONObject>()) {
                //  获取清算资产信息
                val settle_asset = chainMgr.getChainObjectByID(settle_order!!.getJSONObject("balance").getString("asset_id"))
                val settle_asset_precision = settle_asset.getInt("precision")

                //  获取背书资产信息
                val bitasset_data = chainMgr.getChainObjectByID(settle_asset.getString("bitasset_data_id"))
                val short_backing_asset_id = bitasset_data.getJSONObject("options").getString("short_backing_asset")
                val sba_asset = chainMgr.getChainObjectByID(short_backing_asset_id)
                val sba_asset_precision = sba_asset.getInt("precision")

                //  计算喂价
                val n_feed_price = OrgUtils.calcPriceFromPriceObject(bitasset_data.getJSONObject("current_feed").getJSONObject("settlement_price"),
                        short_backing_asset_id,
                        sba_asset_precision, settle_asset_precision, false, BigDecimal.ROUND_DOWN, true)

                //  获取强清补偿系数
                val n_one = BigDecimal.ONE
                val n_force_settlement_offset_percent_add1 = bigDecimalfromAmount(bitasset_data.getJSONObject("options").getString("force_settlement_offset_percent"), 4).add(n_one)

                //  计算清算价格 = 喂价 * （1 + 补偿系数）
                var n_settle_price = n_force_settlement_offset_percent_add1.multiply(n_feed_price)

                //  自动计算base资产
                val settle_asset_symbol = settle_asset.getString("symbol")
                val sba_asset_symbol = sba_asset.getString("symbol")
                val baseAssetSymbol = if (tradingPair != null) {
                    tradingPair._baseAsset.getString("symbol")
                } else {
                    VcUtils.calcBaseAsset(settle_asset_symbol, sba_asset_symbol)
                }

                val issell: Boolean
                val price: Double
                var price_str: String
                val amount_str: String
                val total_str: String
                val base_sym: String
                val quote_sym: String

                val n_balance = bigDecimalfromAmount(settle_order.getJSONObject("balance").getString("amount"), settle_asset_precision)
                if (baseAssetSymbol == settle_asset_symbol) {
                    //  买入 BTS/CNY [清算]
                    issell = false
                    price = n_settle_price.toDouble()
                    price_str = OrgUtils.formatFloatValue(price, settle_asset_precision, has_comma = false)

                    val n_total = n_balance
                    val n_amount = ModelUtils.calculateAverage(n_total, n_settle_price, sba_asset_precision)

                    amount_str = n_amount.toPriceAmountString()
                    total_str = n_total.toPriceAmountString()

                    base_sym = settle_asset_symbol
                    quote_sym = sba_asset_symbol
                } else {
                    //  卖出 CNY/BTS [清算]
                    issell = true
                    n_settle_price = n_one.divide(n_settle_price, kBigDecimalDefaultMaxPrecision, kBigDecimalDefaultRoundingMode)
                    price = n_settle_price.toDouble()
                    price_str = OrgUtils.formatFloatValue(price, sba_asset_precision)

                    val n_amount = n_balance
                    val n_total = ModelUtils.calTotal(n_settle_price, n_amount, sba_asset_precision)

                    amount_str = n_amount.toPriceAmountString()
                    total_str = n_total.toPriceAmountString()

                    base_sym = sba_asset_symbol
                    quote_sym = settle_asset_symbol
                }

                //  REMARK：特殊处理，如果按照 base or quote 的精度格式化出价格为0了，则扩大精度重新格式化。
                if (price_str == "0") {
                    price_str = OrgUtils.formatFloatValue(price, 8)
                }

                _dataArray.add(JSONObject().apply {
                    put("time", settle_order.getString("settlement_date"))
                    put("issettle", true)
                    put("issell", issell)
                    put("price", price_str)
                    put("amount", amount_str)
                    put("total", total_str)
                    put("base_symbol", base_sym)
                    put("quote_symbol", quote_sym)
                    put("id", settle_order.getString("id"))
                    put("seller", settle_order.getString("owner"))
                    put("raw_order", settle_order)  //  原始数据
                })
            }
        }

        //  根据ID升序排列
        if (_dataArray.size > 0) {
            _dataArray.sortBy { it.getString("id").split(".").last().toInt() }
        }
    }

//    private fun onQuerySettlementOrdersResponsed(data_array: JSONArray?, tradingPair: TradingPair?) {
//        //  生成订单数据
//        onGenerateSettlementorders(data_array, tradingPair)
//
//        //  更新显示
//        refreshUI()
//    }

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
                container.addView(ViewOrderCell(_ctx!!, item, _isSettlementsOrder))
            }
        } else {
            val string_no_data = if (_isSettlementsOrder) {
                resources.getString(R.string.kVcOrderTipNoSettleOrder)
            } else {
                resources.getString(R.string.kVcOrderTipNoHistory)
            }
            container.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, string_no_data))
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        super.onCreateView(inflater, container, savedInstanceState)
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
