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
 * [FragmentLoginPrivateKeyMode.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentLoginPrivateKeyMode.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentLoginPrivateKeyMode : Fragment() {
    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var listener: OnFragmentInteractionListener? = null
    private var _ctx: Context? = null
    private var _checkActivePermission = true
    private var _result_promise: Promise? = null

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
    fun initWithCheckActivePermission(checkActivePermission: Boolean, result_promise: Promise?): FragmentLoginPrivateKeyMode {
        _checkActivePermission = checkActivePermission
        _result_promise = result_promise
        return this
    }

    /**
     * 立即导入
     */
    private fun loginBitshares_PrivateKeyMode(active_privatekey: String, trade_password: String) {
        //  检查参数有效性
        if (active_privatekey == "") {
            showToast(_ctx!!.resources.getString(R.string.registerLoginPageCapitalPrivateKeyIsWrongAndInputAgain))
            return
        }

        //  仅正常登录是才需要验证交易密码，导入到已有钱包不用验证。
        if (_checkActivePermission && !Utils.isValidBitsharesWalletPassword(trade_password)) {
            showToast(_ctx!!.resources.getString(R.string.kLoginSubmitTipsTradePasswordFmtIncorrect))
            return
        }

        //  开始登录

        //  从WIF私钥获取公钥。
        val calc_bts_active_address = OrgUtils.genBtsAddressFromWifPrivateKey(active_privatekey)
        if (calc_bts_active_address == null) {
            showToast(_ctx!!.resources.getString(R.string.registerLoginPageCapitalPrivateKeyIsWrongAndInputAgain))
            return
        }

        val mask = ViewMesk(R.string.kTipsBeRequesting.xmlstring(this.activity!!), this.activity!!)
        mask.show()
        ChainObjectManager.sharedChainObjectManager().queryAccountDataHashFromKeys(jsonArrayfrom(calc_bts_active_address)).then {
            val account_data_hash = it as JSONObject
            if (account_data_hash.length() <= 0) {
                mask.dismiss()
                showToast(_ctx!!.resources.getString(R.string.registerLoginPageCapitalPrivateKeyIsWrongAndInputAgain))
                return@then null
            }
            val account_data_list = account_data_hash.values()
            if (account_data_list.length() >= 2) {
                //  TODO:一个私钥关联多个账号的情况处理
            }
            //  默认选择第一个账号
            val account_data = account_data_list.getJSONObject(0)
            return@then ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_data.getString("id")).then {
                mask.dismiss()
                val full_data = it as? JSONObject
                if (full_data == null) {
                    showToast(_ctx!!.resources.getString(R.string.kLoginImportTipsQueryAccountFailed))
                    return@then null
                }
                val account = full_data.getJSONObject("account")
                val accountName = account.getString("name")

                //  正常私钥登录需要验证权限，导入到已有钱包则不用验证。
                if (_checkActivePermission) {
                    //  获取active权限数据
                    val account_active = account.getJSONObject("active")

                    //  检测权限是否足够签署需要active权限的交易。
                    val status = WalletManager.calcPermissionStatus(account_active, jsonObjectfromKVS(calc_bts_active_address, active_privatekey))
                    if (status == EAccountPermissionStatus.EAPS_NO_PERMISSION) {
                        showToast(R.string.kLoginSubmitTipsPrivateKeyIncorrect.xmlstring(_ctx!!))
                        return@then null
                    }
                    if (status == EAccountPermissionStatus.EAPS_PARTIAL_PERMISSION) {
                        showToast(R.string.kLoginSubmitTipsPrivateKeyPermissionNotEnough.xmlstring(_ctx!!))
                        return@then null
                    }
                }

                if (_checkActivePermission) {
                    //  【正常登录】完整钱包模式
                    val full_wallet_bin = WalletManager.sharedWalletManager().genFullWalletData(activity!!, accountName, active_privatekey, null, null, trade_password)
                    //  保存钱包信息
                    AppCacheManager.sharedAppCacheManager().setWalletInfo(AppCacheManager.EWalletMode.kwmPrivateKeyWithWallet.value, full_data, accountName, full_wallet_bin)
                    AppCacheManager.sharedAppCacheManager().autoBackupWalletToWebdir(false)
                    //  导入成功 用交易密码 直接解锁。
                    val unlockInfos = WalletManager.sharedWalletManager().unLock(trade_password, _ctx!!)
                    assert(unlockInfos.getBoolean("unlockSuccess") && unlockInfos.optBoolean("haveActivePermission"))
                    //  [统计]
                    fabricLogCustom("loginEvent", jsonObjectfromKVS("mode", AppCacheManager.EWalletMode.kwmPrivateKeyWithWallet.value, "desc", "privatekey"))
                    //  返回 - 登录成功
                    showToast(_ctx!!.resources.getString(R.string.kLoginTipsLoginOK))
                    activity!!.finish()
                } else {
                    //  【导入到已有钱包】
                    val full_wallet_bin = WalletManager.sharedWalletManager().walletBinImportAccount(accountName, jsonArrayfrom(active_privatekey))!!
                    AppCacheManager.sharedAppCacheManager().apply {
                        updateWalletBin(full_wallet_bin)
                        autoBackupWalletToWebdir(false)
                    }
                    //  重新解锁（即刷新解锁后的账号信息）。
                    val unlockInfos = WalletManager.sharedWalletManager().reUnlock(_ctx!!)
                    assert(unlockInfos.getBoolean("unlockSuccess"))

                    //  返回 - 导入成功
                    showToast(R.string.kWalletImportSuccess.xmlstring(_ctx!!))
                    if (_result_promise != null) {
                        _result_promise!!.resolve(true)
                    }
                    activity!!.finish()
                }
                return@then null
            }
        }.catch {
            mask.dismiss()
            showGrapheneError(it)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        // Inflate the layout for this fragment
        _ctx = inflater.context
        val v = inflater.inflate(R.layout.fragment_login_private_key_mode, container, false)
        val _button_login: Button = v.findViewById(R.id.button_login)
        _button_login.setOnClickListener {
            val active_privatekey = v.findViewById<EditText>(R.id.tf_active_privatekey).text.toString()
            val trade_password = if (_checkActivePermission) v.findViewById<EditText>(R.id.tf_trade_password).text.toString() else ""
            loginBitshares_PrivateKeyMode(active_privatekey, trade_password)
        }
        v.findViewById<ImageView>(R.id.tip_link_active_privatekey).setOnClickListener {
            //  [统计]
            fabricLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_active_privatekey"))
            activity!!.goToWebView(_ctx!!.resources.getString(R.string.kVcTitleWhatIsActivePrivateKey), "http://btspp.io/qam.html#qa_active_privatekey")
        }
        v.findViewById<ImageView>(R.id.tip_link_trading_password).setOnClickListener {
            //  [统计]
            fabricLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_trading_password"))
            activity!!.goToWebView(_ctx!!.resources.getString(R.string.kVcTitleWhatIsTradePassowrd), "http://btspp.io/qam.html#qa_trading_password")
        }
        //  导入到已有钱包：隐藏交易密码。
        if (!_checkActivePermission) {
            v.findViewById<LinearLayout>(R.id.cell_trade_password).visibility = View.GONE
        }
        return v
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
         * @return A new instance of fragment FragmentLoginPrivateKeyMode.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentLoginPrivateKeyMode().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
