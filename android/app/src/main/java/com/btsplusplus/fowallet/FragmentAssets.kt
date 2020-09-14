package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.btsplusplus.fowallet.utils.ModelUtils
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.math.BigInteger
import kotlin.math.pow

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentAssets.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentAssets.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentAssets : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _view: View? = null
    private var _ctx: Context? = null
    private var _detailInfos: JSONObject? = null
    private lateinit var _full_account_data: JSONObject
    private var _isSelfAccount: Boolean = false
    private var _showAllAssets: Boolean = true
    private var _assetDataArray = mutableListOf<JSONObject>()
    private var _total_estimate_value: Double? = null

    //  记账单位 默认CNY
    private var _displayEstimateAsset: String = ""
    //  是否需要2次兑换，如果显示记账单位和核心评估基准资产不同则需要二次换算。即：目标资产->CNY->USD(或其他显示单位)
    private var _needSecondExchange: Boolean = false

    override fun onInitParams(args: Any?) {
        val json_array = args as JSONArray
        _detailInfos = json_array.getJSONObject(0)
        _full_account_data = json_array.getJSONObject(1)

        //  是否是自身帐号判断
        val account_name = _full_account_data.getJSONObject("account").getString("name")
        _isSelfAccount = WalletManager.sharedWalletManager().isMyselfAccount(account_name)

        //  合并资产信息并排序
        var call_orders_hash: JSONObject? = null     //  key:debt_asset_id value:call_orders
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val limitValuesHash = _detailInfos!!.getJSONObject("onorderValuesHash")
        val callValuesHash = _detailInfos!!.getJSONObject("callValuesHash")
        val debtValuesHash = _detailInfos!!.getJSONObject("debtValuesHash")
        val validBalancesHash = _detailInfos!!.getJSONObject("validBalancesHash")
        for (k in validBalancesHash.keys()) {
            val balanceItem = validBalancesHash.getJSONObject(k)
            val asset_type = balanceItem.getString("asset_type")
            val balance = balanceItem.get("balance")
            val balance2 = BigInteger(balanceItem.getString("balance"))

            val asset_detail = chainMgr.getChainObjectByID(asset_type)

            //  智能资产信息
            var bitasset_data: JSONObject? = null
            val bitasset_data_id = asset_detail.optString("bitasset_data_id", "")
            if (bitasset_data_id.isNotEmpty()) {
                bitasset_data = chainMgr.getChainObjectByID(bitasset_data_id)
            }

            val name = asset_detail.getString("symbol")
            val precision = asset_detail.getInt("precision")

            val asset_final = JSONObject()
            asset_final.put("id", asset_type)
            asset_final.put("balance", balance)
            asset_final.put("name", name)
            asset_final.put("precision", precision)

            //  资产类型（核心、智能、普通、预测市场）
            if (asset_type == chainMgr.grapheneCoreAssetID) {
                asset_final.put("is_core", "1")
            } else {
                if (bitasset_data != null) {
                    if (bitasset_data.isTrue("is_prediction_market")) {
                        asset_final.put("is_prediction_market", "1")
                    } else {
                        asset_final.put("is_smart", "1")
                    }
                } else {
                    asset_final.put("is_simple", "1")
                }
            }

            //  总挂单(0显示)
            val limit_order_value = limitValuesHash.opt(asset_type) as? BigInteger
            asset_final.put("limit_order_value", limit_order_value ?: BigInteger("0"))

            //  总抵押(0不显示)
            var optional_number: Int = 0
            val call_order_value = callValuesHash.opt(asset_type) as? BigInteger
            if (call_order_value != null) {
                optional_number++
                asset_final.put("call_order_value", call_order_value)
            }

            //  总债务(0不显示)
            val debt_value = debtValuesHash.opt(asset_type) as? BigInteger
            if (debt_value != null) {
                optional_number++
                asset_final.put("debt_value", debt_value)
                //  有债务则计算强平触发价
                if (call_orders_hash == null) {
                    call_orders_hash = JSONObject()
                    for (call_order in _full_account_data.getJSONArray("call_orders")) {
                        val debt_asset_id = call_order!!.getJSONObject("call_price").getJSONObject("quote").getString("asset_id")
                        call_orders_hash.put(debt_asset_id, call_order)
                    }
                }
                val asset_call_order = call_orders_hash.getJSONObject(asset_type)
                val asset_call_price = asset_call_order.getJSONObject("call_price")
                val collateral_asset_id = asset_call_price.getJSONObject("base").getString("asset_id")
                val collateral_asset = chainMgr.getChainObjectByID(collateral_asset_id)
                //  REMARK：collateral_asset_id 是 debt 的背书资产，那么用户的资产余额里肯定有 抵押中 的背书资产。
                val debt_precision = asset_detail.getInt("precision")
                val collateral_precision = collateral_asset.getInt("precision")

                assert(bitasset_data != null)
                val _mcr = bigDecimalfromAmount(bitasset_data!!.getJSONObject("current_feed").getString("maintenance_collateral_ratio"), 3)
                val trigger_price = OrgUtils.calcSettlementTriggerPrice(asset_call_order.getString("debt"), asset_call_order.getString("collateral"), debt_precision, collateral_precision, _mcr, false, null, true)

                optional_number++
                asset_final.put("trigger_price", trigger_price.toPriceAmountString())
            }

            //  设置优先级   1-BTS   2-主要智能货币（CNY等）    3-有抵押等（其实目前只有BTS可抵押，不排除以后有其他可抵押货币。） 4-其他资产
            var priority: Int = 0
            if (asset_final.optInt("is_core") != 0) {
                priority = 1000
            } else if (asset_detail.getString("issuer") == "1.2.0") {
                //  REMARK：目前主要智能资产都是由 committee-account#1.2.0 帐号发行。
                priority = 100
            } else if (call_order_value != null) {
                priority = 10
            }
            asset_final.put("kPriority", priority)
            asset_final.put("optional_number", optional_number)

            _assetDataArray.add(asset_final)
        }

        //  按照优先级降序排列
        _assetDataArray.sortByDescending { it.getInt("kPriority") }

        //  继续初始化
        _showAllAssets = _assetDataArray.size <= kAppUserAssetDefaultShowNum

        //  默认记账单位
        val defaultEstimateAsset = chainMgr.getDefaultEstimateUnitSymbol()

        //  这个是显示计价单位
        _displayEstimateAsset = SettingManager.sharedSettingManager().getEstimateAssetSymbol()
        _needSecondExchange = _displayEstimateAsset != defaultEstimateAsset
        //  REMARK：
        //  1、所有资产对CNY进行估价，因为如果其他资产直接对USD等计价可能导致没有匹配的交易对，估值误差较大。比如 SEED/CNY 有估值，SEED/JPY 等直接计较则没估值。
        //  2、如果记账单位为USD等、则把CNY计价再转换为USD计价。
        val pairs_list = JSONArray()
        for (asset in _assetDataArray) {
            val quote = asset.getString("name")
            //  记账单位资产，本身不查询。即：CNY/CNY 不查询。
            if (quote == defaultEstimateAsset) {
                continue
            }
            pairs_list.put(jsonObjectfromKVS("base", defaultEstimateAsset, "quote", quote))
        }
        //  添加 二次兑换系数 查询 CNY到USD 的兑换系数 注意：这里以 _displayEstimateAsset 为 base 获取 ticker 数据。
        if (_needSecondExchange) {
            pairs_list.put(jsonObjectfromKVS("base", _displayEstimateAsset, "quote", defaultEstimateAsset))
        }
        ChainObjectManager.sharedChainObjectManager().queryTickerDataByBaseQuoteSymbolArray(pairs_list).then {
            onEstimateDataReached()
            return@then null
        }.catch {
            showToast(_ctx!!.resources.getString(R.string.kVcAssetTipErrorEstimating))
        }
    }

    private fun onEstimateDataReached() {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        var total_estimate_value: Double = 0.0

        //  默认记账单位
        val defaultEstimateAsset = chainMgr.getDefaultEstimateUnitSymbol()

        //  显示精度（以记账单位的精度为准）
        val display_precision = chainMgr.getAssetBySymbol(_displayEstimateAsset).getInt("precision")

        //  计算2次兑换比例，如果核心兑换和显示兑换资产不同，则需要2次兑换。
        var fSecondExchangeRate: Double = 1.0
        if (_needSecondExchange) {
            val ticker = chainMgr.getTickerData(_displayEstimateAsset, defaultEstimateAsset)!!
            fSecondExchangeRate = ticker.getString("latest").toDouble()
        }

        //  1、估算所有资产
        for (asset in _assetDataArray) {
            val quote = asset.getString("name")
            //  如果当前资产为基准资产则特殊计算
            if (quote == defaultEstimateAsset) {
                //  基准资产的估算就是资产自身
                //  REMARK：评估资产总和 = 可用 + 抵押 + 冻结 - 负债。
                val v1 = asset.getString("balance").toDouble()
                val v2 = asset.optString("call_order_value", "0").toDouble()
                val v3 = asset.optString("limit_order_value", "0").toDouble()
                val v4 = asset.optString("debt_value", "0").toDouble()
                val sum_balance = v1 + v2 + v3 - v4
                val fPrecision = 10.0f.pow(asset.getInt("precision"))
                var estimate_value = sum_balance / fPrecision
                //  二次兑换：CNY -> USD
                if (_needSecondExchange) {
                    estimate_value *= fSecondExchangeRate
                }
                asset.put("estimate_value_real", estimate_value)
                asset.put("estimate_value", OrgUtils.formatFloatValue(estimate_value, display_precision))
                total_estimate_value += estimate_value
            } else {
                //  计算资产相对于基准资产（CNY）的价值
                //  REMARK：评估资产总和 = 可用 + 抵押 + 冻结 - 负债。
                val ticker = chainMgr.getTickerData(defaultEstimateAsset, quote)!!
                val v1 = asset.getString("balance").toDouble()
                val v2 = asset.optString("call_order_value", "0").toDouble()
                val v3 = asset.optString("limit_order_value", "0").toDouble()
                val v4 = asset.optString("debt_value", "0").toDouble()
                val sum_balance = v1 + v2 + v3 - v4
                val fPrecision = 10.0f.pow(asset.getInt("precision"))
                //  当前 quote 为显示记账资产（USD），但可能不为核心兑换资产（CNY）
                val estimate_value: Double
                if (_needSecondExchange && quote == _displayEstimateAsset) {
                    estimate_value = sum_balance / fPrecision
                } else {
                    estimate_value = sum_balance / fPrecision * ticker.getString("latest").toDouble() * fSecondExchangeRate
                }
                asset.put("estimate_value_real", estimate_value)
                asset.put("estimate_value", OrgUtils.formatFloatValue(estimate_value, display_precision))
                total_estimate_value += estimate_value
            }
        }

        //  2、考虑排序（按照优先级降序排列、优先级相同则按照估值降序排列）
        val sorter: Comparator<JSONObject> = Comparator { o1, o2 ->
            val o1p = o1.getInt("kPriority")
            val o2p = o2.getInt("kPriority")
            if (o1p == o2p) {
                o2.getDouble("estimate_value_real").compareTo(o1.getDouble("estimate_value_real"))
            } else {
                o2p - o1p
            }
        }
        _assetDataArray.sortWith(sorter)

        _total_estimate_value = total_estimate_value

        //  刷新UI
        refreshUI()
        refreshUI_TotalValue()
    }

    private fun refreshUI_TotalValue(textView: TextView? = null) {
        if (!isAdded) {
            return
        }
        _total_estimate_value?.let { total_estimate_value ->
            val display_precision = ChainObjectManager.sharedChainObjectManager().getAssetBySymbol(_displayEstimateAsset).getInt("precision")
            val label = textView ?: _view!!.findViewById<TextView>(R.id.label_total_value)
            label.text = OrgUtils.formatFloatValue(total_estimate_value, display_precision)
        }
    }

    private fun createCell(ctx: Context, layout_params: LinearLayout.LayoutParams, container: LinearLayout, data: JSONObject) {
        // layout1 左: BTS  Core 右: ≈ 0.022893CNY%
        val ly1 = LinearLayout(ctx)
        ly1.orientation = LinearLayout.HORIZONTAL
        ly1.layoutParams = layout_params
        ly1.setPadding(0, toDp(5.0f), 0, 0)

        val tv1 = TextView(ctx)
        tv1.text = data.getString("name")
        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        tv1.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv1.gravity = Gravity.CENTER_VERTICAL
        tv1.setPadding(0, 0, toDp(4.0f), 0)
        ly1.addView(tv1)

        val isCore = data.optInt("is_core") != 0
        val isPredictionMarket = data.optInt("is_prediction_market") != 0
        val isSmart = data.optInt("is_smart") != 0
        if (isCore || isSmart || isPredictionMarket) {
            val tv2 = TextView(ctx)
            tv2.text = if (isCore) "Core" else if (isSmart) "Smart" else "Prediction"
            tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
            tv2.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            tv2.gravity = Gravity.CENTER_VERTICAL
            tv2.setPadding(4.dp, 1.dp, 4.dp, 1.dp)
            tv2.background = resources.getDrawable(R.drawable.border_text_view)
            ly1.addView(tv2)
        }

        val estimate_value = data.optString("estimate_value", null)
        val tv3 = TextView(ctx)
        if (estimate_value == null) {
            tv3.text = ctx.resources.getString(R.string.kVcAssetTipsEstimating)
            tv3.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            tv3.text = "≈ ${estimate_value}${SettingManager.sharedSettingManager().getEstimateAssetSymbol()}"
            if (data.getDouble("estimate_value_real") >= 0) {
                tv3.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            } else {
                tv3.setTextColor(resources.getColor(R.color.theme01_tintColor))
            }
        }
        tv3.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        tv3.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        var layout_tv3 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_tv3.weight = 1.0f
        layout_tv3.gravity = Gravity.RIGHT
        tv3.layoutParams = layout_tv3
        ly1.addView(tv3)

        // layout2 左: 可用 0.06558 右: 挂单 0
        val ly2 = LinearLayout(ctx)
        ly2.orientation = LinearLayout.HORIZONTAL
        ly2.layoutParams = layout_params

        var value = OrgUtils.formatAssetString(data.getString("balance"), data.getInt("precision"))
        val tv5 = TextView(ctx)
        tv5.text = "${R.string.kLableAvailable.xmlstring(ctx)} ${value}"
        tv5.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        tv5.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv5.gravity = Gravity.CENTER_VERTICAL

        value = OrgUtils.formatAssetString(data.getString("limit_order_value"), data.getInt("precision"))
        val tv6 = TextView(ctx)
        tv6.text = "${R.string.kVcAssetOnOrder.xmlstring(ctx)} ${value}"
        tv6.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        tv6.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv6.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        var layout_tv6 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_tv6.weight = 1.0f
        layout_tv6.gravity = Gravity.RIGHT
        tv6.layoutParams = layout_tv6

        ly2.addView(tv5)
        ly2.addView(tv6)

        //  抵押、负债、强平（可为空）
        var dynamic_layout_list = mutableListOf<LinearLayout>()
        var showIndex = 0
        var dynamic_layout: LinearLayout? = null
        val option_keys = arrayOf("call_order_value", "debt_value", "trigger_price")
        for (key in option_keys) {
            if (data.has(key)) {
                if (dynamic_layout == null) {
                    dynamic_layout = LinearLayout(ctx)
                    dynamic_layout.orientation = LinearLayout.HORIZONTAL
                    dynamic_layout.layoutParams = layout_params
                    dynamic_layout_list.add(dynamic_layout)
                }

                var dynamic_view = TextView(ctx)
                dynamic_layout.addView(dynamic_view)

                dynamic_view.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                dynamic_view.setTextColor(resources.getColor(R.color.theme01_textColorNormal))

                if ((showIndex % 2) == 0) {
                    dynamic_view.gravity = Gravity.CENTER_VERTICAL
                } else {
                    dynamic_view.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                    var layout_tv_right = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                    layout_tv_right.weight = 1.0f
                    layout_tv_right.gravity = Gravity.RIGHT
                    dynamic_view.layoutParams = layout_tv_right
                    //  清除，下一行重新生成。
                    dynamic_layout = null
                }

                val raw_value = data.getString(key)
                if (key == "call_order_value") {
                    dynamic_view.text = "${R.string.kVcAssetColl.xmlstring(ctx)} ${OrgUtils.formatAssetString(raw_value, data.getInt("precision"))}"
                } else if (key == "debt_value") {
                    dynamic_view.text = "${R.string.kVcAssetDebt.xmlstring(ctx)} ${OrgUtils.formatAssetString(raw_value, data.getInt("precision"))}"
                } else {
                    dynamic_view.text = "${R.string.kVcAssetCallPrice.xmlstring(ctx)} ${raw_value}"
                }

                //  增加索引
                showIndex++
            }
        }

        // layout3 左: 转账  右: 交易
        var ly3: LinearLayout? = null
        if (_isSelfAccount) {

            //  TODO:4.0 后续可扩展【更多】按钮
            val actions = jsonArrayfrom(EBitsharesAssetOpKind.ebaok_transfer, EBitsharesAssetOpKind.ebaok_trade)
            if (isSmart || isPredictionMarket) {
                actions.put(EBitsharesAssetOpKind.ebaok_settle)
            } else {
                actions.put(EBitsharesAssetOpKind.ebaok_reserve)
            }
            if (isCore) {
                actions.put(EBitsharesAssetOpKind.ebaok_stake_vote)
            }

            ly3 = LinearLayout(ctx)
            ly3.orientation = LinearLayout.HORIZONTAL
            ly3.layoutParams = layout_params

            val action_weight = 1.0f / actions.length()

            for (action in actions.forin<EBitsharesAssetOpKind>()) {

                val layout_tv7 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                layout_tv7.weight = action_weight
                layout_tv7.gravity = Gravity.LEFT or Gravity.CENTER
                layout_tv7.setMargins(0, 0, 0, 0)

                val tv7 = TextView(ctx)
                when (action!!) {
                    EBitsharesAssetOpKind.ebaok_transfer -> tv7.text = R.string.kVcActivityTypeTransfer.xmlstring(ctx)
                    EBitsharesAssetOpKind.ebaok_trade -> tv7.text = R.string.kVcAssetBtnTrade.xmlstring(ctx)
                    EBitsharesAssetOpKind.ebaok_settle -> tv7.text = R.string.kVcAssetBtnSettle.xmlstring(ctx)
                    EBitsharesAssetOpKind.ebaok_reserve -> tv7.text = R.string.kVcAssetBtnReserve.xmlstring(ctx)
                    EBitsharesAssetOpKind.ebaok_stake_vote -> tv7.text = R.string.kVcAssetBtnStakeVote.xmlstring(ctx)
                    EBitsharesAssetOpKind.ebaok_more -> tv7.text = R.string.kVcAssetBtnMore.xmlstring(ctx)
                    else -> assert(false)
                }
                tv7.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                tv7.setTextColor(resources.getColor(R.color.theme01_color03))
                tv7.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
                tv7.layoutParams = layout_tv7
                tv7.tag = action
                //  单行 尾部截断
                tv7.setSingleLine(true)
                tv7.maxLines = 1
                tv7.ellipsize = TextUtils.TruncateAt.END

                ly3.addView(tv7)

                tv7.setOnClickListener { onActionButtonClicked(data.getString("id"), it.tag as EBitsharesAssetOpKind) }
            }

        }

        // 线
        val lv_line = View(ctx)
        val layout_line = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(1.0f))
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = layout_line
        layout_line.setMargins(0, 0, 0, toDp(6f))

        container.addView(ly1)
        container.addView(ly2)
        for (ly in dynamic_layout_list) {
            container.addView(ly)
        }
        if (ly3 != null) {
            container.addView(ly3)
        }
        container.addView(lv_line)
    }

    private fun onActionButtonClicked(clicked_asset_id: String, tag: EBitsharesAssetOpKind) {
        when (tag) {
            EBitsharesAssetOpKind.ebaok_transfer -> _onTransferClicked(tag, clicked_asset_id)
            EBitsharesAssetOpKind.ebaok_trade -> _onTradeClicked(tag, clicked_asset_id)
            EBitsharesAssetOpKind.ebaok_settle -> _onAssetSettleClicked(tag, clicked_asset_id)
            EBitsharesAssetOpKind.ebaok_reserve -> {
                val value = resources.getString(R.string.kVcAssetOpReserveEntrySafeTips)
                UtilsAlert.showMessageConfirm(activity!!, resources.getString(R.string.kVcHtlcMessageTipsTitle), value).then {
                    if (it != null && it as Boolean) {
                        _onAssetReserveClicked(tag, clicked_asset_id)
                    }
                }
            }
            EBitsharesAssetOpKind.ebaok_stake_vote -> _onAssetStakeVoteClicked(tag, clicked_asset_id)
            else -> assert(false)
        }
    }

    /**
     *  事件 - 资产清算点击
     */
    private fun _onAssetSettleClicked(tag: EBitsharesAssetOpKind, clicked_asset_id: String) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val clicked_asset = chainMgr.getChainObjectByID(clicked_asset_id)
        val oid = clicked_asset.getString("id")
        val bitasset_data_id = clicked_asset.getString("bitasset_data_id")

        val p1 = chainMgr.queryFullAccountInfo(_full_account_data.getJSONObject("account").getString("id"))
        val p2 = chainMgr.queryAllGrapheneObjectsSkipCache(jsonArrayfrom(oid))
        val p3 = chainMgr.queryBackingAsset(clicked_asset)

        activity!!.let { ctx ->
            VcUtils.simpleRequest(ctx, Promise.all(p1, p2, p3)) {
                val data_array = it as JSONArray
                val full_account_data = data_array.getJSONObject(0)
                val result_hash = data_array.getJSONObject(1)
                val backing_asset = data_array.getJSONObject(2)
                val newAsset = result_hash.getJSONObject(oid)
                val newBitassetData = chainMgr.getChainObjectByID(bitasset_data_id)

                //  资产未禁止强清操作 或 全局清算了 才可进行清算操作。
                val hasAlreadyGlobalSettled = ModelUtils.assetHasGlobalSettle(newBitassetData)
                if (!ModelUtils.assetCanForceSettle(newAsset) && !hasAlreadyGlobalSettled) {
                    showToast(resources.getString(R.string.kVcAssetOpSettleTipsDisableSettle))
                    return@simpleRequest
                }

                if (newBitassetData.isTrue("is_prediction_market")) {
                    //   预测市场：必须全局清算之后才可以进行清算操作。
                    if (!hasAlreadyGlobalSettled) {
                        showToast(resources.getString(R.string.kVcAssetOpSettleTipsMustGlobalSettleFirst))
                        return@simpleRequest
                    }
                } else {
                    //  普通智能币
                    //  1、需要有喂价数据才可以进行清算操作。
                    //  2、如果已经黑天鹅了也可以进行清算操作。
                    if (ModelUtils.isNullPrice(newBitassetData.getJSONObject("current_feed").getJSONObject("settlement_price")) &&
                            !hasAlreadyGlobalSettled) {
                        showToast(resources.getString(R.string.kVcAssetOpSettleTipsNoFeedData))
                        return@simpleRequest
                    }
                }

                val settleMsgTips = if (hasAlreadyGlobalSettled) {
                    val n_price = OrgUtils.calcPriceFromPriceObject(newBitassetData.getJSONObject("settlement_price"),
                            newAsset.getString("id"),
                            newAsset.getInt("precision"), backing_asset.getInt("precision"), false, BigDecimal.ROUND_DOWN, true)
                    val global_settle_price = String.format("%s %s/%s", OrgUtils.formatFloatValue(n_price!!.toDouble(), backing_asset.getInt("precision"), has_comma = false),
                            backing_asset.getString("symbol"), newAsset.getString("symbol"))

                    String.format(resources.getString(R.string.kVcAssetOpSettleUiTipsAlreadyGs), global_settle_price)
                } else {
                    val options = newBitassetData.getJSONObject("options")
                    val force_settlement_delay_sec = options.getInt("force_settlement_delay_sec")
                    val s_delay_hour = String.format(resources.getString(R.string.kVcAssetOpSettleDelayHoursN), (force_settlement_delay_sec / 3600).toString())

                    val n_force_settlement_offset_percent = bigDecimalfromAmount(options.getString("force_settlement_offset_percent"), 4)
                    val n_final = n_force_settlement_offset_percent.add(BigDecimal.ONE)

                    String.format(resources.getString(R.string.kVcAssetOpSettleUiTips), s_delay_hour, n_final.toPriceAmountString())
                }
                //  转到清算界面
                val result_promise = Promise()
                ctx.goTo(ActivityAssetOpCommon::class.java, true, args = JSONObject().apply {
                    put("current_asset", clicked_asset)
                    put("full_account_data", full_account_data)
                    put("op_extra_args", JSONObject().apply {
                        put("kOpType", tag)
                        put("kMsgTips", settleMsgTips)
                        put("kMsgAmountPlaceholder", resources.getString(R.string.kVcAssetOpSettleCellPlaceholderAmount))
                        put("kMsgBtnName", resources.getString(R.string.kVcAssetOpSettleBtnName))
                        put("kMsgSubmitInputValidAmount", resources.getString(R.string.kVcAssetOpSettleSubmitTipsPleaseInputAmount))
                        put("kMsgSubmitOK", resources.getString(R.string.kVcAssetOpSettleSubmitTipSettleOK))
                    })
                    put("result_promise", result_promise)
                })
                result_promise.then { dirty ->
                    //  刷新UI
                    if (dirty != null && dirty as Boolean) {
                        //  TODO:5.0 考虑刷新界面
                    }
                }
            }
        }
    }

    /**
     *  事件 - 资产销毁点击
     */
    private fun _onAssetReserveClicked(tag: EBitsharesAssetOpKind, clicked_asset_id: String) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val clicked_asset = chainMgr.getChainObjectByID(clicked_asset_id)
        activity!!.let { ctx ->
            VcUtils.simpleRequest(ctx, chainMgr.queryFullAccountInfo(_full_account_data.getJSONObject("account").getString("id"))) {
                val full_account_data = it as JSONObject
                val result_promise = Promise()
                ctx.goTo(ActivityAssetOpCommon::class.java, true, args = JSONObject().apply {
                    put("current_asset", clicked_asset)
                    put("full_account_data", full_account_data)
                    put("op_extra_args", JSONObject().apply {
                        put("kOpType", tag)
                        put("kMsgTips", resources.getString(R.string.kVcAssetOpReserveUiTips))
                        put("kMsgAmountPlaceholder", resources.getString(R.string.kVcAssetOpReserveCellPlaceholderAmount))
                        put("kMsgBtnName", resources.getString(R.string.kVcAssetOpReserveBtnName))
                        put("kMsgSubmitInputValidAmount", resources.getString(R.string.kVcAssetOpReserveSubmitTipsPleaseInputAmount))
                        put("kMsgSubmitOK", resources.getString(R.string.kVcAssetOpReserveSubmitTipOK))
                    })
                    put("result_promise", result_promise)
                })
                result_promise.then { dirty ->
                    //  刷新UI
                    if (dirty != null && dirty as Boolean) {
                        //  TODO:5.0 考虑刷新界面
                    }
                }
            }
        }
    }

    /**
     *  事件 - 资产锁仓投票
     */
    private fun _onAssetStakeVoteClicked(tag: EBitsharesAssetOpKind, clicked_asset_id: String) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val clicked_asset = chainMgr.getChainObjectByID(clicked_asset_id)
        activity!!.let { ctx ->
            VcUtils.simpleRequest(ctx, chainMgr.queryFullAccountInfo(_full_account_data.getJSONObject("account").getString("id"))) {
                val full_account_data = it as JSONObject
                val result_promise = Promise()
                ctx.goTo(ActivityAssetOpStakeVote::class.java, true, args = JSONObject().apply {
                    put("current_asset", clicked_asset)
                    put("full_account_data", full_account_data)
                    put("result_promise", result_promise)
                })
                result_promise.then { dirty ->
                    //  刷新UI
                    if (dirty != null && dirty as Boolean) {
                        //  TODO:5.0 考虑刷新界面
                    }
                }
            }
        }
    }

    /**
     * 事件 - 转账按钮点击
     */
    private fun _onTransferClicked(tag: EBitsharesAssetOpKind, clicked_asset_id: String) {
        val default_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(clicked_asset_id)
        activity!!.goTo(ActivityTransfer::class.java, true, args = jsonObjectfromKVS("full_account_data", _full_account_data, "default_asset", default_asset))
    }

    /**
     * 事件 - 交易按钮点击
     */
    private fun _onTradeClicked(tag: EBitsharesAssetOpKind, clicked_asset_id: String) {
        //  获取设置界面的计价货币资产。
        val estimateAssetSymbol = SettingManager.sharedSettingManager().getEstimateAssetSymbol()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        //  优先获取计价资产对应的 base 市场信息。
        var baseMarket: JSONObject? = null
        val defaultMarketInfoList = chainMgr.getDefaultMarketInfos()
        for (market in defaultMarketInfoList) {
            val symbol = market!!.getJSONObject("base").getString("symbol")
            if (estimateAssetSymbol == symbol) {
                baseMarket = market
                break
            }
        }

        //  如果计价资产没对应的 base 市场，则获取第一个默认的 CNY 基本市场。（因为：计价资产有许多个，包括欧元等，但 base 市场只有 CNY、USD、BTS 三个而已。）
        if (baseMarket == null) {
            baseMarket = defaultMarketInfoList.first<JSONObject>()
        }

        //  转到交易界面
        var base = chainMgr.getAssetBySymbol(baseMarket!!.getJSONObject("base").getString("symbol"))
        var quote = chainMgr.getChainObjectByID(clicked_asset_id)

        //  REMARK：如果 base 和 quote 相同则特殊处理。CNY/CNY USD/USD BTS/BTS
        var base_symbol = base.getString("symbol")
        var quote_symbol = quote.getString("symbol")
        if (base_symbol == quote_symbol) {
            //  特殊处理
            if (quote_symbol == chainMgr.grapheneAssetSymbol) {
                //  修改 base
                base_symbol = chainMgr.getDefaultParameters().getString("core_default_exchange_asset")
                base = chainMgr.getAssetBySymbol(base_symbol)
            } else {
                //  修改 quote
                quote_symbol = chainMgr.grapheneAssetSymbol
                quote = chainMgr.getAssetBySymbol(quote_symbol)
            }
        }

        //  转到交易界面
        activity!!.let { ctx ->
            val tradingPair = TradingPair().initWithBaseAsset(base, quote)
            VcUtils.simpleRequest(ctx, tradingPair.queryBitassetMarketInfo()) {
                ctx.goTo(ActivityTradeMain::class.java, true, args = jsonArrayfrom(tradingPair, true))
            }
        }
    }

    private fun refreshList(ly: LinearLayout, layout_params: LinearLayout.LayoutParams) {
        var showIndex: Int = 0
        for (item in _assetDataArray) {
            ++showIndex

            val ly_wrap: LinearLayout = LinearLayout(_ctx)
            ly_wrap.orientation = LinearLayout.VERTICAL
            //ly_wrap.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT,toDp(32f))
            ly.addView(ly_wrap)

            if (!_showAllAssets && showIndex == kAppUserAssetDefaultShowNum) {
                val viewAll = TextView(_ctx!!)
                viewAll.text = _ctx!!.resources.getString(R.string.kVcAssetViewAllAssets)
                viewAll.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
                viewAll.setTextColor(resources.getColor(R.color.theme01_color03))
                viewAll.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                val viewAll_layout_param = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(40f))
                viewAll_layout_param.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                ly_wrap.addView(viewAll, viewAll_layout_param)
                ly_wrap.setOnClickListener {
                    _showAllAssets = true
                    refreshUI()
                }
                break
            } else {
                createCell(_ctx!!, layout_params, ly_wrap, item)
            }
        }
    }

    private fun refreshUI() {
        if (!isAdded) {
            return
        }
        val lay: LinearLayout = _view!!.findViewById(R.id.layout_my_assets_from_my_fragment)
        lay.removeAllViews()
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(30f))
        layout_params.gravity = Gravity.CENTER_VERTICAL
        refreshList(lay, layout_params)
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        _ctx = inflater.context

        val v: View = inflater.inflate(R.layout.fragment_assets, container, false)
        val ly = v.findViewById<LinearLayout>(R.id.layout_my_assets_from_my_fragment)
        v.findViewById<TextView>(R.id.label_total_title).text = String.format(_ctx!!.resources.getString(R.string.kVcAssetTotalValue), SettingManager.sharedSettingManager().getEstimateAssetSymbol())
        refreshUI_TotalValue(v.findViewById<TextView>(R.id.label_total_value))

        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(30f))
        layout_params.gravity = Gravity.CENTER_VERTICAL
        refreshList(ly, layout_params)

        _view = v
        return v
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
