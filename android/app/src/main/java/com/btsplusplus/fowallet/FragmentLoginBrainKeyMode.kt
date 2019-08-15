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
import android.widget.LinearLayout
import bitshares.*
import com.btsplusplus.fowallet.utils.CommonLogic
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONObject

// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentLoginBrainKeyMode.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentLoginBrainKeyMode.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentLoginBrainKeyMode : Fragment() {

    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var _ctx: Context? = null
    private var listener: OnFragmentInteractionListener? = null
    private var _checkActivePermission = true
    private var _result_promise: Promise? = null

    private var _tf_bran_key: EditText? = null
    private var _tf_trade_password: EditText? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            param1 = it.getString(ARG_PARAM1)
            param2 = it.getString(ARG_PARAM2)
        }
    }

    /**
     * 初始化
     */
    fun initWithCheckActivePermission(checkActivePermission: Boolean, result_promise: Promise?): FragmentLoginBrainKeyMode {
        _checkActivePermission = checkActivePermission
        _result_promise = result_promise
        return this
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        _ctx = inflater.context
        val v = inflater.inflate(R.layout.fragment_login_brain_key_mode, container, false)

        val _button_login: Button = v.findViewById(R.id.button_login_from_brain_key_mode)

        _tf_bran_key = v.findViewById(R.id.tf_brain_key)
        _tf_trade_password = v.findViewById(R.id.tf_trade_password_from_brain_key_mode)

        //  导入到已有钱包：隐藏交易密码。
        if (!_checkActivePermission) {
            v.findViewById<LinearLayout>(R.id.cell_trade_password_from_brain_key_mode).visibility = View.GONE
        }

        _button_login.setOnClickListener {
            onLoginClicked()
        }

        v.findViewById<ImageView>(R.id.tip_link_trading_password_from_brain_key_mode).setOnClickListener {
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_trading_password"))
            activity!!.goToWebView(_ctx!!.resources.getString(R.string.kVcTitleWhatIsTradePassowrd), "https://btspp.io/qam.html#qa_trading_password")
        }

        return v
    }

    private fun onLoginClicked() {

        var bran_key = _tf_bran_key!!.text.toString()
        if (bran_key == "") {
            showToast(_ctx!!.resources.getString(R.string.kLoginSubmitTipsBrainKeyIncorrect))
            return
        }
        bran_key = WalletManager.normalizeBrainKey(bran_key)

        //  仅正常登录是才需要验证交易密码，导入到已有钱包不用验证。
        var trade_password = ""
        if (_checkActivePermission) {
            trade_password = _tf_trade_password!!.text.toString()
            if (!Utils.isValidBitsharesWalletPassword(trade_password)) {
                showToast(_ctx!!.resources.getString(R.string.kLoginSubmitTipsTradePasswordFmtIncorrect))
                return
            }
        }

        //  开始登录
        val pub_pri_keys_hash = JSONObject()

        //  根据BIP32、BIP39、BIP44规范，从助记词生成种子、和各种子私钥。
        val hdk = HDWallet.fromMnemonic(bran_key)
        val new_key_owner = hdk.deriveBitshares(EHDBitsharesPermissionType.ehdbpt_owner)
        val new_key_active = hdk.deriveBitshares(EHDBitsharesPermissionType.ehdbpt_active)
        val new_key_memo = hdk.deriveBitshares(EHDBitsharesPermissionType.ehdbpt_memo)

        val pri_key_owner = new_key_owner.toWifPrivateKey()
        val pri_key_active = new_key_active.toWifPrivateKey()
        val pri_key_memo = new_key_memo.toWifPrivateKey()

        val pub_key_owner = OrgUtils.genBtsAddressFromWifPrivateKey(pri_key_owner)
        val pub_key_active = OrgUtils.genBtsAddressFromWifPrivateKey(pri_key_active)
        val pub_key_memo = OrgUtils.genBtsAddressFromWifPrivateKey(pri_key_memo)

        pub_pri_keys_hash.put(pub_key_owner, pri_key_owner)
        pub_pri_keys_hash.put(pub_key_active, pri_key_active)
        pub_pri_keys_hash.put(pub_key_memo, pri_key_memo)

        //  REMARK：兼容轻钱包，根据序列生成私钥匙。
        for (i in 0 until 10) {
            val pri_key = WalletManager.genPrivateKeyFromBrainKey(bran_key, i)
            val pub_key = OrgUtils.genBtsAddressFromWifPrivateKey(pri_key)
            pub_pri_keys_hash.put(pub_key, pri_key)
        }

        //  从各种私钥登录。
        CommonLogic.loginWithKeyHashs(activity!!, pub_pri_keys_hash, _checkActivePermission, trade_password,
                AppCacheManager.EWalletMode.kwmBrainKeyWithWallet.value,
                "login with brainkey",
                _ctx!!.resources.getString(R.string.kLoginSubmitTipsBrainKeyIncorrect),
                _ctx!!.resources.getString(R.string.kLoginSubmitTipsPermissionNotEnoughAndCannotBeImported),
                _result_promise)
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

    companion object {
        /**
         * Use this factory method to create a new instance of
         * this fragment using the provided parameters.
         *
         * @param param1 Parameter 1.
         * @param param2 Parameter 2.
         * @return A new instance of fragment FragmentLoginBrainKeyMode.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentLoginBrainKeyMode().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
