package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import bitshares.*
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
 * [FragmentRegisterWalletMode.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentRegisterWalletMode.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentRegisterWalletMode : Fragment() {
    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var listener: OnFragmentInteractionListener? = null
    private var _ctx: Context? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            param1 = it.getString(ARG_PARAM1)
            param2 = it.getString(ARG_PARAM2)
        }
    }

    private fun onRegisterClicked(account_name: String, password: String, confirm_password: String, refcode: String) {
        //  检测参数有效性
        if (!Utils.isValidBitsharesAccountName(account_name)) {
            showToast(R.string.kLoginSubmitTipsAccountFmtIncorrect.xmlstring(_ctx!!))
            return
        }
        if (!Utils.isValidBitsharesWalletPassword(password)) {
            showToast(R.string.kLoginSubmitTipsPasswordFmtIncorrect.xmlstring(_ctx!!))
            return
        }
        if (confirm_password != password) {
            showToast(R.string.kLoginSubmitTipsConfirmPasswordFailed.xmlstring(_ctx!!))
            return
        }

        //   --- 开始注册 ---
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this.activity!!), this.activity!!)
        mask.show()
        //  1、查询名字是否被占用。
        val username = account_name.toLowerCase()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        chainMgr.isAccountExistOnBlockChain(username).then {
            if (it != null && it as Boolean) {
                mask.dismiss()
                showToast(R.string.kLoginSubmitTipsAccountAlreadyExist.xmlstring(_ctx!!))
                return@then null
            }
            //  2、调用水龙头API注册
            val private_owner = WalletManager.randomPrivateKeyWIF()
            val private_active = WalletManager.randomPrivateKeyWIF()
            val owner_key = OrgUtils.genBtsAddressFromWifPrivateKey(private_owner)!!
            val active_key = OrgUtils.genBtsAddressFromWifPrivateKey(private_active)!!
            val args = jsonObjectfromKVS("account_name", username,
                    "owner_key", owner_key,
                    "active_key", active_key,
                    "memo_key", active_key,
                    "chid", kAppChannelID,
                    "referrer_code", refcode)
            OrgUtils.asyncPost(chainMgr.getFinalFaucetURL(), args).then {
                val response = it as JSONObject
                //  注册失败
                if (response.getInt("status") != 0) {
                    mask.dismiss()
                    //  [统计]
                    btsppLogCustom("faucetFailed", response)
                    activity!!.showFaucetRegisterError(response)
                    return@then null
                }
                //  3、注册成功
                val full_wallet_bin = WalletManager.sharedWalletManager().genFullWalletData(activity!!, username, jsonArrayfrom(private_active, private_owner), password)
                //  查询完整帐号信息
                chainMgr.queryFullAccountInfo(username).then {
                    mask.dismiss()
                    val new_full_account_data = it as? JSONObject
                    if (new_full_account_data == null) {
                        AppCacheManager.sharedAppCacheManager().setWalletInfo(AppCacheManager.EWalletMode.kwmFullWalletMode.value, null, username, full_wallet_bin)
                        showToast(R.string.kLoginTipsWalletModeRegOK.xmlstring(_ctx!!))
                        return@then null
                    }
                    //  保存钱包信息
                    AppCacheManager.sharedAppCacheManager().setWalletInfo(AppCacheManager.EWalletMode.kwmFullWalletMode.value, new_full_account_data, username, full_wallet_bin)
                    //  导入成功 用交易密码 直接解锁。
                    val unlockInfos = WalletManager.sharedWalletManager().unLock(password, _ctx!!)
                    assert(unlockInfos.getBoolean("unlockSuccess") && unlockInfos.optBoolean("haveActivePermission"))
                    //  [统计]
                    btsppLogCustom("registerEvent", jsonObjectfromKVS("mode", AppCacheManager.EWalletMode.kwmFullWalletMode.value, "desc", "wallet"))
                    showToast(R.string.kLoginTipsRegFullOK.xmlstring(_ctx!!))
                    activity!!.goTo(ActivityIndexMy::class.java, true, back = true)
                    return@then null
                }.catch {
                    mask.dismiss()
                    AppCacheManager.sharedAppCacheManager().setWalletInfo(AppCacheManager.EWalletMode.kwmFullWalletMode.value, null, username, full_wallet_bin)
                    showToast(R.string.kLoginTipsWalletModeRegOK.xmlstring(_ctx!!))
                }
                return@then null
            }
            return@then null
        }.catch {
            mask.dismiss()
            showToast(_ctx!!.resources.getString(R.string.tip_network_error))
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        // Inflate the layout for this fragment
        val view = inflater.inflate(R.layout.fragment_register_wallet_mode, container, false)
        _ctx = inflater.context
        view.findViewById<Button>(R.id.btn_register).setOnClickListener {
            val account_name = view.findViewById<EditText>(R.id.tf_account_name).text.toString()
            val password = view.findViewById<EditText>(R.id.tf_password).text.toString()
            val confirm_password = view.findViewById<EditText>(R.id.tf_confirm_password).text.toString()
            val refcode = view.findViewById<EditText>(R.id.tf_refcode).text.toString()
            onRegisterClicked(account_name, password, confirm_password, refcode)
        }
        view.findViewById<ImageView>(R.id.tip_account_name).setOnClickListener { UtilsAlert.showMessageBox(activity!!, R.string.kLoginRegTipsAccountFormat.xmlstring(_ctx!!)) }
        view.findViewById<ImageView>(R.id.tip_password).setOnClickListener { UtilsAlert.showMessageBox(activity!!, R.string.kLoginRegTipsWalletPasswordFormat.xmlstring(_ctx!!)) }
        view.findViewById<ImageView>(R.id.tip_refcode).setOnClickListener {
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_refcode"))
            activity!!.goToWebView(_ctx!!.resources.getString(R.string.kVcTitleWhatIsRefcode), "https://btspp.io/qam.html#qa_refcode")
        }
        return view
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
         * @return A new instance of fragment FragmentRegisterWalletMode.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentRegisterWalletMode().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
