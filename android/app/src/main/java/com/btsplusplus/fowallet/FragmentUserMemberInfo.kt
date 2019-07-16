package com.btsplusplus.fowallet

import android.app.Activity
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.util.Base64
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONObject

// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentUserMemberInfo.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentUserMemberInfo.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentUserMemberInfo : BtsppFragment() {
    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var listener: OnFragmentInteractionListener? = null

    private lateinit var _ctx: Context
    private var _view: View? = null

    private lateinit var tv_account_status: TextView
    private lateinit var tv_my_referrer_code: TextView
    private lateinit var tv_member_tip: TextView
    private lateinit var btn_upgrade: Button
    private var _myReferrerCode: String? = null

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        val v: View = inflater.inflate(R.layout.fragment_user_member_info, container, false)
        _view = v

        _ctx = inflater.context

        //  初始化UI信息
        val full_account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
        val account = full_account_data.getJSONObject("account")
        tv_account_status = v.findViewById(R.id.txt_account_status)
        tv_my_referrer_code = v.findViewById(R.id.txt_my_referrer_code)
        v.findViewById<TextView>(R.id.txt_account_id).text = account.getString("id")
        v.findViewById<TextView>(R.id.txt_account_name).text = account.getString("name")
        tv_member_tip = v.findViewById(R.id.txt_upgrade_to_member_tip)
        btn_upgrade = v.findViewById<Button>(R.id.button_upgrade_member)

        if (Utils.isBitsharesVIP(account.getString("membership_expiration_date"))) {
            refreshUILefttimeMember(account)
        } else {
            refreshUINormalMember()
            //  binding events
            btn_upgrade.setOnClickListener {
                upgradeMemberButtonOnClick()
            }
        }
        return v
    }

    private fun _encodeMyRefCode(account_id: String): String {
        val uid = account_id.split(".").last()
        return Base64.encodeToString(uid.toByteArray(), Base64.URL_SAFE or Base64.NO_WRAP)
    }

    private fun refreshUILefttimeMember(account_data: JSONObject) {
        _myReferrerCode = _encodeMyRefCode(account_data.getString("id"))
        tv_account_status.text = resources.getString(R.string.kLblMembershipLifetime)
        tv_my_referrer_code.text = _myReferrerCode
        tv_my_referrer_code.setTextColor(resources.getColor(R.color.theme01_buyColor))
        tv_member_tip.text = resources.getString(R.string.kAccountUpgradeTipsMember)
        tv_member_tip.setTextColor(resources.getColor(R.color.theme01_buyColor))
        btn_upgrade.visibility = View.INVISIBLE
        //  copy ref code
        _view?.let {
            it.findViewById<LinearLayout>(R.id.id_my_referrer_code_layout).setOnClickListener {
                if (_myReferrerCode != null) {
                    if (Utils.copyToClipboard(activity!!, _myReferrerCode!!)) {
                        showToast(resources.getString(R.string.kAccountMembershipMyRefCodeCopyOK))
                    }
                }
            }
        }
    }

    private fun refreshUINormalMember() {
        tv_account_status.text = resources.getString(R.string.kLblMembershipBasic)
        tv_my_referrer_code.text = resources.getString(R.string.kAccountMembershipNoRefCode)
        tv_my_referrer_code.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv_member_tip.text = resources.getString(R.string.kAccountUpgradeTipsNotMember)
        tv_member_tip.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        btn_upgrade.visibility = View.VISIBLE
    }

    private fun upgradeMemberButtonOnClick() {
        upgradeToLifetimeMember()
    }

    private fun gotoUpgradeToLifetimeMemberCore(op_data: JSONObject, fee_item: JSONObject, account_data: JSONObject) {
        //  adjust fee
        op_data.put("fee", fee_item)

        val account_id = account_data.getString("id")

        //  确保有权限发起普通交易，否则作为提案交易处理。
        (_ctx as Activity).GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_account_upgrade, false, false,
                op_data, account_data) { isProposal, _ ->
            assert(!isProposal)

            //  请求网络广播
            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), _ctx)
            mask.show()

            BitsharesClientManager.sharedBitsharesClientManager().accountUpgrde(op_data).then {
                //  升级成功、继续请求、刷新界面。
                ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_id).then {
                    mask.dismiss()

                    //  升级会员成功，保存新数据。
                    val full_data = it as JSONObject
                    AppCacheManager.sharedAppCacheManager().updateWalletAccountInfo(full_data)

                    //  刷新界面
                    refreshUILefttimeMember(full_data.getJSONObject("account"))

                    showToast(resources.getString(R.string.kAccountUpgradeMemberSubmitTxFullOK))
                    btsppLogCustom("txUpgradeToLifetimeMemberFullOK", jsonObjectfromKVS("account", account_id))
                }.catch {
                    mask.dismiss()
                    showToast(resources.getString(R.string.kAccountUpgradeMemberSubmitTxOK))
                    btsppLogCustom("txUpgradeToLifetimeMemberOK", jsonObjectfromKVS("account", account_id))
                }
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txUpgradeToLifetimeMemberFailed", jsonObjectfromKVS("account", account_id))
            }
        }
    }

    private fun upgradeToLifetimeMember() {
        val full_account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
        val account_info = full_account_data.getJSONObject("account")

        val op_data = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", BTS_NETWORK_CORE_ASSET_ID)
            })
            put("account_to_upgrade", account_info.getString("id"))
            put("upgrade_to_lifetime_member", true)
        }

        val act = _ctx as Activity

        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), _ctx)
        mask.show()

        BitsharesClientManager.sharedBitsharesClientManager().calcOperationFee(op_data, EBitsharesOperations.ebo_account_upgrade).then {
            mask.dismiss()

            val fee_price_item = it as JSONObject
            val price = OrgUtils.formatAssetAmountItem(fee_price_item)

            act.alerShowMessageConfirm(resources.getString(R.string.kWarmTips), String.format(resources.getString(R.string.kAccountUpgradeMemberCostAsk), price)).then {
                if (it != null && it as Boolean) {
                    act.guardWalletUnlocked(false) { unlocked ->
                        if (unlocked) {
                            gotoUpgradeToLifetimeMemberCore(op_data, fee_price_item, account_info)
                        }
                    }
                }
                return@then null
            }

            return@then null
        }.catch {
            mask.dismiss()
            showToast(_ctx.resources.getString(R.string.tip_network_error))
        }
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

    companion object {
        /**
         * Use this factory method to create a new instance of
         * this fragment using the provided parameters.
         *
         * @param param1 Parameter 1.
         * @param param2 Parameter 2.
         * @return A new instance of fragment FragmentUserMemberInfo.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentUserMemberInfo().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
