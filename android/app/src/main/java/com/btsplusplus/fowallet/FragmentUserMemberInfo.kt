package com.btsplusplus.fowallet

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONObject

//import org.bitshares.app.R

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

    private lateinit var tv_account_status: TextView
    private lateinit var tv_member_tip: TextView
    private lateinit var _tv_account_status: TextView
    private lateinit var tip_fee_confirmation: AlertDialog


    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        val v: View = inflater.inflate(R.layout.fragment_user_member_info, container, false)
        _ctx = inflater.context

        //  初始化UI信息
        val full_account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
        val account = full_account_data.getJSONObject("account")
        tv_account_status = v.findViewById<TextView>(R.id.txt_account_status)
        v.findViewById<TextView>(R.id.txt_account_id).text = account.getString("id")
        v.findViewById<TextView>(R.id.txt_account_name).text = account.getString("name")

        tv_member_tip = v.findViewById<TextView>(R.id.txt_upgrade_to_member_tip)


        val account_info = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        assert(account_info != null);
        if (Utils.isBitsharesVIP(account_info.getString("membership_expiration_date"))) {
            refreshUILefttimeMember()
        } else {
            refreshUINormalMember()
        }

        // Todo 升级终身会员 click
        v.findViewById<Button>(R.id.button_upgrade_member).setOnClickListener {
            upgradeMemberButtonOnClick()
        }


        return v
    }

    private fun refreshUILefttimeMember(){
        tv_account_status.text = resources.getString(R.string.kLblMembershipLifetime)
        tv_member_tip.text = resources.getString(R.string.kAccountUpgradeTipsMember)
        tv_member_tip.setTextColor(resources.getColor(R.color.theme01_buyColor))
    }

    private fun refreshUINormalMember(){
        tv_account_status.text = resources.getString(R.string.kLblMembershipBasic)
        tv_member_tip.text = resources.getString(R.string.kAccountUpgradeTipsNotMember)
        tv_member_tip.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
    }


    private fun upgradeMemberButtonOnClick(){
        upgradeToLifetimeMember()
    }

    private fun gotoUpgradeToLifetimeMemberCore(op_data: JSONObject, fee_item: JSONObject, account_data: JSONObject ){
        var m_opdata :JSONObject = JSONObject(op_data.toString())
        m_opdata.put("fee", fee_item)
        val op_data = JSONObject(m_opdata.toString())

        val account_id = account_data.getString("id")


        //  确保有权限发起普通交易，否则作为提案交易处理。
        (_ctx as Activity).GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_account_upgrade, false, false,
                op_data, account_data) { isProposal, fee_paying_account ->
            assert(!isProposal)

            //  请求网络广播
            val mesk = ViewMesk("${resources.getString(R.string.nameRequesting)}...",_ctx)
            mesk.show()


            BitsharesClientManager.sharedBitsharesClientManager().accountUpgrde(op_data).then{
                val data = it as JSONObject

                //  升级成功、继续请求、刷新界面。
                return@then ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_id).then{
                    val full_data = it as JSONObject
                    mesk.dismiss()
                    // 升级会员成功，保存新数据。
                    assert(full_data != null)
                    AppCacheManager.sharedAppCacheManager().updateWalletAccountInfo(full_data)

                    // 刷新界面
                    refreshUILefttimeMember()

                    showToast(resources.getString(R.string.kAccountUpgradeMemberSubmitTxFullOK))
                    fabricLogCustom("txUpgradeToLifetimeMemberOK", jsonObjectfromKVS("account", account_id))


                }

            }.catch { err ->
                mesk.dismiss()
                showGrapheneError(err)
                //  [统计]
                fabricLogCustom("txUpgradeToLifetimeMemberFailed", jsonObjectfromKVS("account", account_id))
            }
        }

    }

    private fun upgradeToLifetimeMember() {

        val json_account_info = WalletManager.sharedWalletManager().getWalletAccountInfo()
        assert(json_account_info != null)

        val account_info = json_account_info!!.getJSONObject("account")
        assert(account_info != null)

        val op_data = JSONObject().apply {
            put("fee",JSONObject().apply {
                put("amount",0)
                put("asset_id",BTS_NETWORK_CORE_ASSET_ID)
            })
            put("account_to_upgrade",account_info.getString("id"))
            put("upgrade_to_lifetime_member",true)
        }

        val mesk = ViewMesk("${resources.getString(R.string.nameRequesting)}...",_ctx)
        mesk.show()

        BitsharesClientManager.sharedBitsharesClientManager().calcOperationFee(op_data, EBitsharesOperations.ebo_account_upgrade).then {
            mesk.dismiss()
            val fee_price_item = it as JSONObject
            val price = OrgUtils.formatAssetAmountItem(fee_price_item)

            // Todo 弹窗提示 @"升级终身会员需要花费 %@，是否继续？
            tip_fee_confirmation = ViewSelector.show(_ctx,String.format(resources.getString(R.string.kAccountUpgradeMemberCostAsk),price), arrayOf("是","否")){ _index: Int, result: String ->

                if (_index == 0) {

                    (_ctx as Activity).guardWalletUnlocked(false) { unlocked ->
                        if (unlocked) {
                            gotoUpgradeToLifetimeMemberCore(op_data,fee_price_item,account_info)
                        }
                    }

                }
                tip_fee_confirmation.dismiss()
            }
            null
        }.catch {
            mesk.dismiss()
            showToast(_ctx!!.resources.getString(R.string.nameNetworkException))
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
