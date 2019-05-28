package com.btsplusplus.fowallet

import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.support.v4.app.FragmentActivity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import bitshares.AppCacheManager
import com.fowallet.walletcore.bts.WalletManager

// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentUserBaseInfo.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentUserBaseInfo.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentUserBaseInfo : BtsppFragment() {
    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var listener: OnFragmentInteractionListener? = null
    private lateinit var mActivity: FragmentActivity

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        mActivity = activity!!

        val v: View = inflater.inflate(R.layout.fragment_user_base_info, container, false)

        //  初始化 设置备份按钮是否可见
        val hexwallet_bin = AppCacheManager.sharedAppCacheManager().getWalletInfo().optString("kFullWalletBin", "")
        val button_backup_wallet = v.findViewById<Button>(R.id.button_backup_wallet)
        if (hexwallet_bin == "") {
            button_backup_wallet.visibility = android.view.View.GONE
        } else {
            button_backup_wallet.visibility = android.view.View.VISIBLE
        }

        //  初始化UI信息
        val full_account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
        val account = full_account_data.getJSONObject("account")
        v.findViewById<TextView>(R.id.txt_account_id).text = account.getString("id")
        v.findViewById<TextView>(R.id.txt_account_name).text = account.getString("name")
        v.findViewById<TextView>(R.id.txt_referrer_name).text = full_account_data.getString("referrer_name")
        v.findViewById<TextView>(R.id.txt_registrar_name).text = full_account_data.getString("registrar_name")
        v.findViewById<TextView>(R.id.txt_lifetime_referrer_name).text = full_account_data.getString("lifetime_referrer_name")

        //  备份钱包
        button_backup_wallet.setOnClickListener {
            backupWallet()
        }

        //  注销
        v.findViewById<Button>(R.id.button_logout).setOnClickListener {
            gotoLogout()
        }

        return v
    }

    private fun gotoLogout() {
        mActivity.alerShowMessageConfirm(resources.getString(R.string.kWarmTips), resources.getString(R.string.kAccTipsLogout)).then {
            if (it != null && it as Boolean) {
                gotoLogoutCore()
            }
            return@then null
        }
    }

    private fun gotoLogoutCore() {
        //  内存钱包锁定、导入钱包删除。
        WalletManager.sharedWalletManager().Lock()
        AppCacheManager.sharedAppCacheManager().removeWalletInfo()
        //  返回
        mActivity.finish()
    }

    private fun backupWallet() {
        mActivity.goTo(ActivityWalletBackup::class.java, true)
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
         * @return A new instance of fragment FragmentUserBaseInfo.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentUserBaseInfo().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
