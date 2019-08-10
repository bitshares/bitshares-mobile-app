package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import bitshares.Promise
import bitshares.btsppLogCustom
import bitshares.jsonObjectfromKVS

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

        _button_login.setOnClickListener({
            onLoginClicked()
        })

        v.findViewById<ImageView>(R.id.tip_link_trading_password_from_brain_key_mode).setOnClickListener({
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_trading_password"))
            activity!!.goToWebView(_ctx!!.resources.getString(R.string.kVcTitleWhatIsTradePassowrd), "https://btspp.io/qam.html#qa_trading_password")
        })

        return v
    }

    private fun onLoginClicked() {
        val bran_key = _tf_bran_key!!.text
        val trade_password = _tf_trade_password!!.text
        if (_checkActivePermission){

        } else {

        }
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
