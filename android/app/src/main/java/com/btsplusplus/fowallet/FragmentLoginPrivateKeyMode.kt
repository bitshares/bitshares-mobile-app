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
            showToast(_ctx!!.resources.getString(R.string.kLoginSubmitTipsInvalidPrivateKey))
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
            showToast(_ctx!!.resources.getString(R.string.kLoginSubmitTipsInvalidPrivateKey))
            return
        }

        //  从各种私钥登录。
        CommonLogic.loginWithKeyHashs(activity!!, jsonObjectfromKVS(calc_bts_active_address, active_privatekey), _checkActivePermission, trade_password,
                AppCacheManager.EWalletMode.kwmPrivateKeyWithWallet.value,
                "login with privatekey",
                R.string.kLoginSubmitTipsPrivateKeyIncorrect.xmlstring(_ctx!!),
                R.string.kLoginSubmitTipsPermissionNotEnoughAndCannotBeImported.xmlstring(_ctx!!),
                _result_promise)
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
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_active_privatekey"))
            activity!!.goToWebView(_ctx!!.resources.getString(R.string.kVcTitleWhatIsActivePrivateKey), "https://btspp.io/qam.html#qa_active_privatekey")
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
