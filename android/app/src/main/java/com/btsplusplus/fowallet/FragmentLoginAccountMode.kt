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
 * [FragmentLoginAccountMode.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentLoginAccountMode.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentLoginAccountMode : Fragment() {
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
    fun initWithCheckActivePermission(checkActivePermission: Boolean, result_promise: Promise?): FragmentLoginAccountMode {
        _checkActivePermission = checkActivePermission
        _result_promise = result_promise
        return this
    }

    /**
     * 处理登录
     */
    private fun loginBitshares_AccountMode(account_name: String, password: String, trade_password: String) {
        //  TODO:登录逻辑

        //  TODO:检查参数有效性
        if (account_name.isEmpty()) {
            showToast(_ctx!!.resources.getString(R.string.kLoginSubmitTipsAccountIsEmpty))
            return
        }
        if (password.isEmpty()) {
            showToast(_ctx!!.resources.getString(R.string.kMsgPasswordCannotBeNull))
            return
        }

        //  正常登录才需要验证交易密码。
        if (_checkActivePermission && !Utils.isValidBitsharesWalletPassword(trade_password)) {
            showToast(_ctx!!.resources.getString(R.string.kLoginSubmitTipsTradePasswordFmtIncorrect))
            return
        }

        //  开始请求
        val username = account_name.toLowerCase()
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this.activity!!), this.activity!!)
        mask.show()
        ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(username).then {
            mask.dismiss()
            val full_data = it as? JSONObject
            if (full_data == null) {
                showToast(_ctx!!.resources.getString(R.string.kLoginSubmitTipsAccountIsNotExist))
                return@then null
            }

            //  获取active权限数据
            val account_active = full_data.getJSONObject("account").getJSONObject("active")

            //  根据密码计算active私钥
            val active_seed = "${username}active${password}"
            val calc_bts_active_address = OrgUtils.genBtsAddressFromPrivateKeySeed(active_seed)!!

            //  权限检查
            val status = WalletManager.calcPermissionStatus(account_active, jsonObjectfromKVS(calc_bts_active_address, true))
            //  a、无任何权限，不导入。
            if (status == EAccountPermissionStatus.EAPS_NO_PERMISSION) {
                showToast(R.string.kLoginSubmitTipsAccountPasswordIncorrect.xmlstring(_ctx!!))
                return@then null
            }
            //  b、部分权限，仅在导入钱包可以，直接登录时不支持。
            if (_checkActivePermission && status == EAccountPermissionStatus.EAPS_PARTIAL_PERMISSION) {
                showToast(R.string.kLoginSubmitTipsAccountPasswordPermissionNotEnough.xmlstring(_ctx!!))
                return@then null
            }

            if (_checkActivePermission) {
                //  【正常登录】
                //  导入账号
                if (trade_password != "") {
                    //  生成钱包信息
                    val active_private_wif = OrgUtils.genBtsWifPrivateKey(active_seed.utf8String())
                    val owner_seed = "${username}owner${password}"
                    val owner_private_wif = OrgUtils.genBtsWifPrivateKey(owner_seed.utf8String())
                    val full_wallet_bin = WalletManager.sharedWalletManager().genFullWalletData(activity!!, username, jsonArrayfrom(active_private_wif, owner_private_wif), trade_password)
                    assert(full_wallet_bin != null)

                    //  保存钱包信息
                    AppCacheManager.sharedAppCacheManager().setWalletInfo(AppCacheManager.EWalletMode.kwmPasswordWithWallet.value, full_data, username, full_wallet_bin)
                    AppCacheManager.sharedAppCacheManager().autoBackupWalletToWebdir(false)

                    //  导入成功 用交易密码 直接解锁。
                    val unlockInfos = WalletManager.sharedWalletManager().unLock(trade_password, _ctx!!)
                    assert(unlockInfos.getBoolean("unlockSuccess") && unlockInfos.optBoolean("haveActivePermission"))
                } else {
                    //  单纯密码模式
                    AppCacheManager.sharedAppCacheManager().setWalletInfo(AppCacheManager.EWalletMode.kwmPasswordOnlyMode.value, full_data, username, null)
                    //  导入成功 用帐号密码 直接解锁。
                    val unlockInfos = WalletManager.sharedWalletManager().unLock(password, _ctx!!)
                    assert(unlockInfos.getBoolean("unlockSuccess") && unlockInfos.optBoolean("haveActivePermission"))
                }
                //  [统计]
                btsppLogCustom("loginEvent", jsonObjectfromKVS("mode", AppCacheManager.EWalletMode.kwmPasswordWithWallet.value, "desc", "password+wallet"))
                //  返回 - 登录成功
                showToast(_ctx!!.resources.getString(R.string.kLoginTipsLoginOK))
                activity!!.finish()
            } else {
                //  【导入到已有钱包】
                val active_private_wif = OrgUtils.genBtsWifPrivateKey(active_seed.utf8String())
                val owner_seed = "${username}owner${password}"
                val owner_private_wif = OrgUtils.genBtsWifPrivateKey(owner_seed.utf8String())

                //  导入账号到钱包BIN文件中
                val full_wallet_bin = WalletManager.sharedWalletManager().walletBinImportAccount(username, jsonArrayfrom(active_private_wif, owner_private_wif))!!
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
        }.catch { err ->
            mask.dismiss()
            showGrapheneError(err)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        // Inflate the layout for this fragment
        _ctx = inflater.context
        val v: View = inflater.inflate(R.layout.fragment_login_account_mode, container, false)
        val _button_login: Button = v.findViewById(R.id.button_login)
        _button_login.setOnClickListener {
            var tf_account_name: EditText = v.findViewById(R.id.tf_account_name)
            val account_name = tf_account_name.text.toString()
            var tf_password: EditText = v.findViewById(R.id.tf_password)
            val password = tf_password.text.toString()
            var trade_password = ""
            if (_checkActivePermission) {
                var tf_trade_password: EditText = v.findViewById(R.id.tf_trade_password)
                trade_password = tf_trade_password.text.toString()
            }
            loginBitshares_AccountMode(account_name, password, trade_password)
        }
        v.findViewById<ImageView>(R.id.tip_link_trading_password).setOnClickListener {
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_trading_password"))
            activity!!.goToWebView(_ctx!!.resources.getString(R.string.kVcTitleWhatIsTradePassowrd), "https://btspp.io/qam.html#qa_trading_password")
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
         * @return A new instance of fragment FragmentLoginAccountMode.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentLoginAccountMode().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
