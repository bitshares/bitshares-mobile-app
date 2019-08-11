package com.btsplusplus.fowallet

import android.content.Context
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import bitshares.*
import com.btsplusplus.fowallet.ViewEx.TextViewEx
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.max

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentVestingBalance.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentVestingBalance.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentVestingBalance : BtsppFragment() {

    private var _data_array = mutableListOf<JSONObject>()
    private var _ctx: Context? = null
    private var _view: View? = null
    private var _full_account_data: JSONObject? = null
    private var _isSelfAccount = false

    override fun onInitParams(args: Any?) {
        _full_account_data = args as JSONObject
        _isSelfAccount = WalletManager.sharedWalletManager().isMyselfAccount(_full_account_data!!.getJSONObject("account").getString("name"))
    }

    fun queryVestingBalance() {
        if (_full_account_data == null) {
            return
        }

        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        activity?.let { ctx ->
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
            mask.show()

            val account = _full_account_data!!.getJSONObject("account")
            val uid = account.getString("id")

            val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            val p1 = conn.async_exec_db("get_vesting_balances", jsonArrayfrom(uid))
            val p2 = conn.async_exec_db("get_workers_by_account", jsonArrayfrom(uid))
            val p3 = conn.async_exec_db("get_witness_by_account", jsonArrayfrom(uid))

            Promise.all(p1, p2, p3).then {
                val all_data = it as JSONArray

                val vesting_balance_name_hash = JSONObject()

                val data_array = all_data.getJSONArray(0)
                val data_workers = all_data.optJSONArray(1)
                val data_witness = all_data.optJSONObject(2)
                data_workers?.forEach<JSONObject> { nullable_worker ->
                    val worker = nullable_worker!!
                    if (OrgUtils.getWorkerType(worker) == EBitsharesWorkType.ebwt_vesting.value) {
                        val balance = worker.getJSONArray("worker").getJSONObject(1).optString("balance", null)
                        if (balance != null) {
                            val name = worker.optString("name", null)
                                    ?: R.string.kVestingCellNameWorkerFunds.xmlstring(_ctx!!)
                            vesting_balance_name_hash.put(balance, name)
                        }
                    }
                }
                if (data_witness != null) {
                    val pay_vb = data_witness.optString("pay_vb", null)
                    if (pay_vb != null) {
                        vesting_balance_name_hash.put(pay_vb, R.string.kVestingCellNameWitnessFunds.xmlstring(_ctx!!))
                    }
                }
                val cashback_vb = account.optString("cashback_vb", null)
                if (cashback_vb != null) {
                    vesting_balance_name_hash.put(cashback_vb, R.string.kVestingCellNameCashbackFunds.xmlstring(_ctx!!))
                }

                val asset_ids = JSONObject()
                data_array.forEach<JSONObject> { nullable_vesting ->
                    asset_ids.put(nullable_vesting!!.getJSONObject("balance").getString("asset_id"), true)
                }
                return@then chainMgr.queryAllAssetsInfo(asset_ids.keys().toJSONArray()).then {
                    mask.dismiss()
                    onQueryVestingBalanceResponsed(data_array, vesting_balance_name_hash)
                    return@then null
                }
            }.catch {
                mask.dismiss()
                showToast(resources.getString(R.string.tip_network_error))
            }

            return@let
        }
    }

    private fun onQueryVestingBalanceResponsed(data_array: JSONArray, nameHash: JSONObject) {
        //  更新数据
        _data_array.clear()

        if (data_array.length() > 0) {
            for (it in data_array.forin<JSONObject>()) {
                val vesting = it!!
                val oid = vesting.getString("id")
                //  略过总金额为 0 的待解冻金额对象。
                if (vesting.getJSONObject("balance").getString("amount").toLong() == 0L) {
                    continue
                }
                //  linear_vesting_policy = 0,
                //  cdd_vesting_policy = 1,
                //  instant_vesting_policy = 2,
                when (vesting.getJSONArray("policy").getInt(0)) {
                    EBitsharesVestingPolicy.ebvp_cdd_vesting_policy.value,
                    EBitsharesVestingPolicy.ebvp_instant_vesting_policy.value -> {
                        var name = nameHash.optString(oid, null)
                        if (name == null) {
                            val balance_type = vesting.optString("balance_type", null)
                            if (balance_type != null && balance_type.toLowerCase() == "market_fee_sharing") {
                                name = R.string.kVestingCellNameMarketFeeSharing.xmlstring(_ctx!!)
                            }
                        }
                        if (name == null) {
                            name = R.string.kVestingCellNameCustomVBO.xmlstring(_ctx!!)
                        }
                        vesting.put("kName", name)
                        _data_array.add(vesting)
                    }
                    else -> {
                        //  TODO:ebvp_linear_vesting_policy
                        //  TODO:fowallet 1.7 暂时不支持 linear_vesting_policy
                    }
                }
            }
        }

        //  根据ID降序排列
        _data_array.sortByDescending { it.getString("id").split(".").last().toInt() }

        //  更新显示
        _view?.let { view ->
            val container: LinearLayout = view.findViewById(R.id.layout_vesting_balance_cell)
            container.removeAllViews()
            if (_data_array.size > 0) {
                refreshUI(container)
            } else {
                container.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, R.string.kVestingTipsNoData.xmlstring(_ctx!!)))
            }
        }
    }

    private fun refreshUI(container: LinearLayout) {
        _data_array.forEachIndexed { idx, vesting ->
            val name = vesting.getString("kName")

            val balance = vesting.getJSONObject("balance")
            val balance_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(balance.getString("asset_id"))
            val balance_asset_symbol = balance_asset.getString("symbol")

            var vestingPeriodValue = "--"
            when (vesting.getJSONArray("policy").getInt(0)) {
                EBitsharesVestingPolicy.ebvp_cdd_vesting_policy.value -> {
                    //  REMARK：解冻周期最低1秒
                    val policy_data = vesting.getJSONArray("policy").getJSONObject(1)
                    val vesting_seconds = max(policy_data.getLong("vesting_seconds"), 1L)
                    vestingPeriodValue = Utils.fmtVestingPeriodDateString(_ctx!!, vesting_seconds)
                }
                EBitsharesVestingPolicy.ebvp_instant_vesting_policy.value -> {
                    vestingPeriodValue = R.string.kVestingCellPeriodInstant.xmlstring(_ctx!!)
                }
                EBitsharesVestingPolicy.ebvp_linear_vesting_policy.value -> {
                    //  TODO:不支持
                    assert(false)
                }
            }

            val precision = balance_asset.getInt("precision")

            //  format values
            val total_amount = OrgUtils.formatAssetString(balance.getString("amount"), precision)
            val unfreeze_number = OrgUtils.formatAssetString(Utils.calcVestingBalanceAmount(vesting).toString(), precision)
            val unfreeze_cycle = vestingPeriodValue

            //  line1 name & button
            val layout_line1 = LinearLayout(_ctx)
            val layout_line1_params = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
            layout_line1_params.setMargins(0, 10.dp, 0, 0)
            layout_line1.layoutParams = layout_line1_params
            val tv_balance = TextViewEx(_ctx!!, "${idx + 1}. $name", dp_size = 13.0f, bold = true, color = R.color.theme01_textColorMain, gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL)
            layout_line1.addView(tv_balance)
            if (_isSelfAccount) {
                val tv_pickup = TextViewEx(_ctx!!, R.string.kVestingCellBtnWithdrawal.xmlstring(_ctx!!), dp_size = 13.0f, color = R.color.theme01_textColorHighlight, gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL, width = LLAYOUT_MATCH)
                layout_line1.addView(tv_pickup)
                // click event
                tv_pickup.setOnClickListener { onWithdrawButtonClicked(vesting) }
            }

            //  line2 title
            val layout_line2 = LinearLayout(_ctx)
            val layout_line2_params = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
            layout_line2_params.setMargins(0, 10.dp, 0, 0)
            layout_line2.layoutParams = layout_line2_params
            val tv_total_amount = TextViewEx(_ctx!!, "${R.string.kVestingCellTotal.xmlstring(_ctx!!)}($balance_asset_symbol)", dp_size = 11.0f, color = R.color.theme01_textColorGray, width = 0.dp, weight = 1.0f, gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL)
            val tv_unfreeze_amount = TextViewEx(_ctx!!, "${R.string.kVestingCellVesting.xmlstring(_ctx!!)}($balance_asset_symbol)", dp_size = 11.0f, color = R.color.theme01_textColorGray, width = 0.dp, weight = 1.0f, gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL)
            val tv_unfreeze_cycle = TextViewEx(_ctx!!, R.string.kVestingCellPeriod.xmlstring(_ctx!!), dp_size = 11.0f, color = R.color.theme01_textColorGray, width = 0.dp, weight = 1.0f, gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL)
            layout_line2.addView(tv_total_amount)
            layout_line2.addView(tv_unfreeze_amount)
            layout_line2.addView(tv_unfreeze_cycle)

            //  line3 value
            val layout_line3 = LinearLayout(_ctx)
            val layout_line3_params = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
            layout_line3_params.setMargins(0, 10.dp, 0, 10.dp)
            layout_line3.layoutParams = layout_line3_params
            val tv_total_amount_value = TextViewEx(_ctx!!, total_amount, dp_size = 12.0f, color = R.color.theme01_textColorNormal, width = 0.dp, weight = 1.0f, gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL)
            val tv_unfreeze_amount_value = TextViewEx(_ctx!!, unfreeze_number, dp_size = 12.0f, color = R.color.theme01_textColorNormal, width = 0.dp, weight = 1.0f, gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL)
            val tv_unfreeze_cycle_value = TextViewEx(_ctx!!, unfreeze_cycle, dp_size = 12.0f, color = R.color.theme01_textColorNormal, width = 0.dp, weight = 1.0f, gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL)
            layout_line3.addView(tv_total_amount_value)
            layout_line3.addView(tv_unfreeze_amount_value)
            layout_line3.addView(tv_unfreeze_cycle_value)

            container.apply {
                addView(layout_line1)
                addView(layout_line2)
                addView(layout_line3)
                addView(ViewLine(_ctx!!))
            }
        }
    }

    private fun onWithdrawButtonClicked(vesting: JSONObject) {
        val policy = vesting.getJSONArray("policy")

        when (policy.getInt(0)) {
            //  验证提取日期
            EBitsharesVestingPolicy.ebvp_cdd_vesting_policy.value -> {
                val policy_data = policy.getJSONObject(1)
                val start_claim = policy_data.getString("start_claim")
                val start_claim_ts = Utils.parseBitsharesTimeString(start_claim)
                val now_ts = Utils.now_ts()
                if (now_ts <= start_claim_ts) {
                    val d = Date(start_claim_ts * 1000)
                    val f = SimpleDateFormat("yyyy-MM-dd HH:mm:ss")
                    val s = f.format(d)
                    showToast(String.format(R.string.kVestingTipsStartClaim.xmlstring(_ctx!!), s))
                    return
                }
            }
            //  不用额外验证
            EBitsharesVestingPolicy.ebvp_instant_vesting_policy.value -> {
            }
            EBitsharesVestingPolicy.ebvp_linear_vesting_policy.value -> {
                assert(false)   //  TODO:不支持
            }
        }

        //  计算可提取数量
        val withdraw_available = Utils.calcVestingBalanceAmount(vesting)
        if (withdraw_available <= 0) {
            showToast(R.string.kVestingTipsAvailableZero.xmlstring(_ctx!!))
            return
        }

        //  ----- 准备提取 -----

        //  1、判断手续费是否足够。
        val extra_balance = JSONObject().apply {
            put(vesting.getJSONObject("balance").getString("asset_id"), withdraw_available)
        }
        val fee_item = ChainObjectManager.sharedChainObjectManager().getFeeItem(EBitsharesOperations.ebo_vesting_balance_withdraw, _full_account_data, extra_balance = extra_balance)
        if (!fee_item.getBoolean("sufficient")) {
            showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }

        //  2、解锁钱包or账号
        activity!!.guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                processWithdrawVestingBalanceCore(vesting, _full_account_data!!, fee_item, withdraw_available)
            }
        }
    }

    private fun processWithdrawVestingBalanceCore(vesting: JSONObject, full_account_data: JSONObject, fee_item: JSONObject, withdraw_available: Long) {
        val balance_id = vesting.getString("id")
        val balance = vesting.getJSONObject("balance")

        val account = full_account_data.getJSONObject("account")
        val uid = account.getString("id")

        val op = JSONObject().apply {
            put("fee", jsonObjectfromKVS("amount", 0, "asset_id", fee_item.getString("fee_asset_id")))
            put("vesting_balance", balance_id)
            put("owner", uid)
            put("amount", jsonObjectfromKVS("amount", withdraw_available, "asset_id", balance.getString("asset_id")))
        }

        //  确保有权限发起普通交易，否则作为提案交易处理。
        activity!!.GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_vesting_balance_withdraw, false, false,
                op, account) { isProposal, _ ->
            assert(!isProposal)
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this.activity!!), this.activity!!)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().vestingBalanceWithdraw(op).then {
                mask.dismiss()
                showToast(String.format(R.string.kVestingTipTxVestingBalanceWithdrawFullOK.xmlstring(_ctx!!), balance_id))
                //  [统计]
                btsppLogCustom("txVestingBalanceWithdrawFullOK", jsonObjectfromKVS("account", uid))
                //  刷新
                queryVestingBalance()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txVestingBalanceWithdrawFailed", jsonObjectfromKVS("account", uid))
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        _ctx = inflater.context
        val view = inflater.inflate(R.layout.fragment_vesting_balance, container, false)
        _view = view
        return view
    }

}
