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
 * [FragmentAssetsDetail.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentAssetsDetail.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentAssetsDetail : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _ctx: Context? = null
    private var _loadStartID: Int = 0
    private var _full_account_data: JSONObject? = null
    private var _loading: Boolean = true
    private var _dataArray = mutableListOf<JSONObject>()

    override fun onInitParams(args: Any?) {
        if ( args != null ) {
            _full_account_data = args as JSONObject
            queryAccountHistory()
        }
    }

    private fun queryAccountHistory() {
        _loading = true

        //  查询最新的 100 条记录。
        val stop = "1.${EBitsharesObjectType.ebot_operation_history.value}.0"
        val start = "1.${EBitsharesObjectType.ebot_operation_history.value}.${_loadStartID}"
        //  start - 从指定ID号往前查询（包含该ID号），如果指定ID为0，则从最新的历史记录往前查询。结果包含 start。
        //  stop  - 指定停止查询ID号（结果不包含该ID），如果指定为0，则查询到最早的记录位置（or达到limit停止。）结果不包含该 stop ID。
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        conn.async_exec_history("get_account_history", jsonArrayfrom(_full_account_data!!.getJSONObject("account").getString("id"), stop, 100, start)).then {
            return@then onGetAccountHistoryResponsed(it as JSONArray)
        }.catch {
            _loading = false
            showToast(_ctx!!.resources.getString(R.string.nameNetworkException))
        }
    }

    private fun onGetAccountHistoryResponsed(data_array: JSONArray): Promise {
        val block_num_hash = JSONObject()
        val asset_id_hash = JSONObject()
        val account_id_hash = JSONObject()
        for (history in data_array) {
            if (history == null) {
                continue
            }
            block_num_hash.put(history.getString("block_num"), true)
            val op = history.getJSONArray("op")
            val op_data = op[1] as JSONObject
            //  手续费资产查询
            val fee = op_data.optJSONObject("fee")
            if (fee != null) {
                asset_id_hash.put(fee.getString("asset_id"), true)
            }
            //  获取每项操作需要额外查询到信息（资产ID、帐号ID等）
            val op_code = op[0] as Int
            when (op_code) {
                EBitsharesOperations.ebo_transfer.value -> {
                    account_id_hash.put(op_data.getString("from"), true)
                    account_id_hash.put(op_data.getString("to"), true)
                    asset_id_hash.put(op_data.getJSONObject("amount").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_limit_order_create.value -> {
                    account_id_hash.put(op_data.getString("seller"), true)
                    asset_id_hash.put(op_data.getJSONObject("amount_to_sell").getString("asset_id"), true)
                    asset_id_hash.put(op_data.getJSONObject("min_to_receive").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_limit_order_cancel.value -> {
                    account_id_hash.put(op_data.getString("fee_paying_account"), true)
                }
                EBitsharesOperations.ebo_call_order_update.value -> {
                    account_id_hash.put(op_data.getString("funding_account"), true)
                    asset_id_hash.put(op_data.getJSONObject("delta_collateral").getString("asset_id"), true)
                    asset_id_hash.put(op_data.getJSONObject("delta_debt").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_fill_order.value -> {
                    account_id_hash.put(op_data.getString("account_id"), true)
                    asset_id_hash.put(op_data.getJSONObject("pays").getString("asset_id"), true)
                    asset_id_hash.put(op_data.getJSONObject("receives").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_account_create.value -> {
                    account_id_hash.put(op_data.getString("registrar"), true)
                }
                EBitsharesOperations.ebo_account_update.value -> {
                    account_id_hash.put(op_data.getString("account"), true)
                }
                EBitsharesOperations.ebo_account_upgrade.value -> {
                    account_id_hash.put(op_data.getString("account_to_upgrade"), true)
                }
                else -> {
                    //  TODO:fowallet 其他类型的操作 额外处理。重要！！！！
                }
            }
        }

        //  额外查询 各种操作以来的资产信息、帐号信息、时间信息等
        val block_num_list = block_num_hash.keys().toJSONArray()
        val asset_id_list = asset_id_hash.keys().toJSONArray()
        val account_id_list = account_id_hash.keys().toJSONArray()

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val p1 = chainMgr.queryAllAssetsInfo(asset_id_list)
        val p2 = chainMgr.queryAllAccountsInfo(account_id_list)
        val p3 = chainMgr.queryAllBlockHeaderInfos(block_num_list, false)

        return Promise.all(p1, p2, p3).then {
            onQueryAccountHistoryDetailResponsed(data_array)
            return@then true
        }
    }

    private fun onQueryAccountHistoryDetailResponsed(data_array: JSONArray) {
        _loading = false
        _dataArray.clear()

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val assetBasePriority = chainMgr.genAssetBasePriorityHash()
        for (history in data_array) {
            if (history == null) {
                continue
            }
            val block_num = history.getString("block_num")
            val block_header = chainMgr.getBlockHeaderInfoByBlockNumber(block_num)
            //  根据操作op构造显示内容
            val op = history.getJSONArray("op")
            val op_data = op[1] as JSONObject
            val op_code = op[0] as Int

            var transferName: String? = null
            var mainDesc: String = _ctx!!.resources.getString(R.string.myAssetsPageUnknowOperationContent)
            var transferNameColor: Int? = null
            //  处理要显示的操作类型 TODO:fowallet 待完善添加支持更多。
            //  TODO:fowallet 各种细节优化、比如更新账户 投票独立出来 等等。买单卖单独立等等。
            //  TODO:fowallet 考虑着色
            when (op_code) {
                EBitsharesOperations.ebo_transfer.value -> {
                    transferName = R.string.myAssetsPageOpNameTransfer.xmlstring(_ctx!!)
                    val from = chainMgr.getChainObjectByID(op_data.getString("from")).getString("name")
                    val to = chainMgr.getChainObjectByID(op_data.getString("to")).getString("name")
                    val amount = op_data.getJSONObject("amount")
                    val asset = chainMgr.getChainObjectByID(amount.getString("asset_id"))
                    val num = OrgUtils.formatAssetString(amount.getString("amount"), asset.getInt("precision"))
                    val symbol = asset.getString("symbol")
                    mainDesc = String.format(R.string.myAssetsPageTransferFormat.xmlstring(_ctx!!), from, "${num}${symbol}", to)
                }
                EBitsharesOperations.ebo_limit_order_create.value -> {
                    val user = chainMgr.getChainObjectByID(op_data.getString("seller")).getString("name")
                    val info = OrgUtils.calcOrderDirectionInfos(assetBasePriority, op_data.getJSONObject("amount_to_sell"), op_data.getJSONObject("min_to_receive"))

                    val base_symbol = info.getJSONObject("base").getString("symbol")
                    val quote_symbol = info.getJSONObject("quote").getString("symbol")
                    val str_price = info.getString("str_price")
                    val str_quote = info.getString("str_quote")

                    if (info.getBoolean("issell")) {
                        transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameCreateSellOrder)
                        transferNameColor = R.color.theme01_sellColor
                        mainDesc = String.format(R.string.myAssetsPageSubmitSellOrder.xmlstring(_ctx!!), user, "${str_price}${base_symbol}/${quote_symbol}", "${str_quote}${quote_symbol}")
                    } else {
                        transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameCreateBuyOrder)
                        transferNameColor = R.color.theme01_buyColor
                        mainDesc = String.format(R.string.myAssetsPageSubmitBuyOrder.xmlstring(_ctx!!), user, "${str_price}${base_symbol}/${quote_symbol}", "${str_quote}${quote_symbol}")
                    }
                }
                EBitsharesOperations.ebo_limit_order_cancel.value -> {
                    transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameCancelOrder)
                    val user = chainMgr.getChainObjectByID(op_data.getString("fee_paying_account")).getString("name")
                    val oid = op_data.getString("order").split(".").last()
                    mainDesc = String.format(R.string.myAssetsPageCancelLimitOrder.xmlstring(_ctx!!), user, oid)
                }
                EBitsharesOperations.ebo_call_order_update.value -> {
                    transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameUpdatePosition)
                    val user = chainMgr.getChainObjectByID(op_data.getString("funding_account")).getString("name")
                    //  REMARK：这2个字段可能为负数。
                    val delta_collateral = op_data.getJSONObject("delta_collateral")
                    val delta_debt = op_data.getJSONObject("delta_debt")
                    val collateral_asset = chainMgr.getChainObjectByID(delta_collateral.getString("asset_id"))
                    val debt_asset = chainMgr.getChainObjectByID(delta_debt.getString("asset_id"))
                    val n_coll = OrgUtils.formatAssetString(delta_collateral.getString("amount"), collateral_asset.getInt("precision"))
                    val n_debt = OrgUtils.formatAssetString(delta_debt.getString("amount"), debt_asset.getInt("precision"))
                    val symbol_coll = collateral_asset.getString("symbol")
                    val symbol_debt = debt_asset.getString("symbol")
                    mainDesc = String.format(R.string.myAssetsPageUpdateMarginMoney.xmlstring(_ctx!!), user, "${n_coll}${symbol_coll}", "${n_debt}${symbol_debt}")
                }
                EBitsharesOperations.ebo_fill_order.value -> {
                    transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameFillOrder)

                    val user = chainMgr.getChainObjectByID(op_data.getString("account_id")).getString("name")
                    val isCallOrder = op_data.getString("order_id").split(".")[1].toInt() == EBitsharesObjectType.ebot_call_order.value
                    val info = OrgUtils.calcOrderDirectionInfos(assetBasePriority, op_data.getJSONObject("pays"), op_data.getJSONObject("receives"))

                    val base_symbol = info.getJSONObject("base").getString("symbol")
                    val quote_symbol = info.getJSONObject("quote").getString("symbol")
                    val str_price = info.getString("str_price")
                    val str_quote = info.getString("str_quote")

                    if (info.getBoolean("issell")) {
                        mainDesc = String.format(R.string.myAssetsPageFillSellOrder.xmlstring(_ctx!!), user, "${str_price}${base_symbol}/${quote_symbol}", "${str_quote}${quote_symbol}")
                    } else {
                        mainDesc = String.format(R.string.myAssetsPageFillBuyOrder.xmlstring(_ctx!!), user, "${str_price}${base_symbol}/${quote_symbol}", "${str_quote}${quote_symbol}")
                    }
                    if (isCallOrder) {
                        transferNameColor = R.color.theme01_callOrderColor
                    }
                }
                EBitsharesOperations.ebo_account_create.value -> {
                    transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameCreateAccount)
                    val user = chainMgr.getChainObjectByID(op_data.getString("registrar")).getString("name")
                    var new_user = op_data.getString("name")
                    mainDesc = String.format(R.string.myAssetsPageCreatedAccount.xmlstring(_ctx!!), user, new_user)
                }
                EBitsharesOperations.ebo_account_update.value -> {
                    transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameUpdateAccount)
                    val user = chainMgr.getChainObjectByID(op_data.getString("account")).getString("name")
                    mainDesc = "${user} ${_ctx!!.resources.getString(R.string.myAssetsPageUpdatedAccount)}"
                }
                EBitsharesOperations.ebo_account_upgrade.value -> {
                    if (op_data.optBoolean("upgrade_to_lifetime_member", false)) {
                        transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameUpgradeAccount)
                        val user = chainMgr.getChainObjectByID(op_data.getString("account_to_upgrade")).getString("name")
                        mainDesc = "${user} ${_ctx!!.resources.getString(R.string.myAssetsPageUpgradedLifelongAccount)}"
                    }
                }
                EBitsharesOperations.ebo_proposal_create.value -> {
                    transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameCreateProposal)
                    mainDesc = "${_ctx!!.resources.getString(R.string.myAssetsPageCreateProposal)}"
                }
                EBitsharesOperations.ebo_proposal_update.value -> {
                    transferName = _ctx!!.resources.getString(R.string.myAssetsPageOpNameUpdateProposal)
                    val oid = op_data.getString("proposal").split(".").last()
                    mainDesc = "${_ctx!!.resources.getString(R.string.myAssetsPageUpdateProposal)} #${oid}"
                }
                else -> {
                    //  TODO:fowallet 其他类型的操作 额外处理。重要！！！！
                }
            }
            //  REMARK：未知操作不显示，略过。
            if (transferName == null) {
                continue
            }

            //  添加到列表
            val item = JSONObject()
            item.put("typename", transferName)
            item.put("desc", mainDesc)
            item.put("block_time", block_header?.getString("timestamp") ?: "")
            item.put("history", history)
            if (transferNameColor != null) {
                item.put("typecolor", transferNameColor)
            }
            _dataArray.add(item)
        }

        //  刷新
        refreshUI()
    }

    /**
     * 合并账户历史中的订单成交条目
     */
    private fun mergeFillOrderHistory(data_array: JSONArray): JSONArray {
        //  TODO:未完成，暂不合并。
        return data_array
    }

    private fun refreshUI() {
        val act = this.activity
        if (act != null) {
            val container: LinearLayout = act.findViewById(R.id.layout_my_assets_detail_from_my_fragment)
            container.removeAllViews()
            if (_dataArray.size > 0) {
                val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                layout_params.gravity = Gravity.CENTER_VERTICAL
                for (item in _dataArray) {
                    createCell(container, layout_params, _ctx!!, item)
                }
            } else {
                container.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, _ctx!!.resources.getString(R.string.myAssetsPageNotAnyActivityInfo)))
            }
        }
    }

    private fun createCell(ly: LinearLayout, layout_params: LinearLayout.LayoutParams, ctx: Context, data: JSONObject) {
        val ly_wrap = LinearLayout(ctx)
        ly_wrap.orientation = LinearLayout.VERTICAL

        // layout1
        val ly1 = LinearLayout(ctx)
        ly1.orientation = LinearLayout.HORIZONTAL
        ly1.layoutParams = layout_params
        ly1.setPadding(0, toDp(5.0f), 0, 0)

        val tv1 = TextView(ctx)
        tv1.text = data.getString("typename")
        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        //  设置颜色
        if (data.has("typecolor")) {
            tv1.setTextColor(resources.getColor(data.getInt("typecolor")))
        } else {
            tv1.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
        tv1.gravity = Gravity.CENTER_VERTICAL

        val tv2 = TextView(ctx)
        tv2.text = Utils.fmtAccountHistoryTimeShowString(data.getString("block_time"))
        tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10.0f)
        tv2.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv2.gravity = Gravity.TOP or Gravity.RIGHT
        var layout_tv2 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_tv2.weight = 1.0f
        layout_tv2.gravity = Gravity.RIGHT
        tv2.layoutParams = layout_tv2

        ly1.addView(tv1)
        ly1.addView(tv2)

        // layout2
        val ly2 = LinearLayout(ctx)
        ly2.orientation = LinearLayout.HORIZONTAL
        ly2.layoutParams = layout_params

        val tv5 = TextView(ctx)
        tv5.text = data.getString("desc")
        tv5.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv5.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv5.gravity = Gravity.CENTER_VERTICAL
        tv5.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        tv5.setPadding(0, 0, 0, toDp(6f))

        ly2.addView(tv5)

        // 线
        val lv_line = View(ctx)
        var layout_line = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(1.0f))
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = layout_line

        ly_wrap.addView(ly1)
        ly_wrap.addView(ly2)
        ly_wrap.addView(lv_line)

        ly.addView(ly_wrap)
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        _ctx = inflater.context
        val v: View = inflater.inflate(R.layout.fragment_assets_detail, container, false)
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
