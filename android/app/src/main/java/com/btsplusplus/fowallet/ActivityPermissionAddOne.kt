package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.EditText
import bitshares.OrgUtils
import bitshares.Promise
import bitshares.TempManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_permission_add_one.*
import org.json.JSONObject

class ActivityPermissionAddOne : BtsppActivity() {

    private lateinit var _result_promise: Promise

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_permission_add_one)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _result_promise = args.get("result_promise") as Promise

        layout_back_from_add_one_permission.setOnClickListener {
            finish()
        }

        //  搜索账号
        btn_search.setOnClickListener {
            TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
                last_activity.goTo(ActivityPermissionAddOne::class.java, true, back = true)
                val tf = findViewById<EditText>(R.id.tf_authority_name)
                tf.setText(it.getString("name"))
                tf.setSelection(tf.text.toString().length)
            }
            goTo(ActivityAccountQueryBase::class.java, true)
        }

        //  提交按钮
        btn_submitt_from_add_one_permission.setOnClickListener {
            _onSubmitClicked()
        }
    }

    private fun _onSubmitClicked() {
        val str_authority = findViewById<EditText>(R.id.tf_authority_name).text.toString().trim()
        val str_weight = findViewById<EditText>(R.id.tf_weight).text.toString().trim()

        //  有效性检查
        if (str_authority == "") {
            showToast(resources.getString(R.string.kVcPermissionAddOneDoneTipsInvalidAuthority))
            return
        }

        val i_threshold = str_weight.toIntOrNull()
        if (i_threshold == null || i_threshold < 1 || i_threshold > 65535) {
            showToast(resources.getString(R.string.kVcPermissionAddOneDoneTipsInvalidWeight))
            return
        }

        //  判断输入的是账号还是公钥
        if (OrgUtils.isValidBitsharesPublicKey(str_authority)) {
            onAddOneDone(str_authority, str_authority, false, i_threshold)
        } else {
            //  无效公钥，判断是不是有效的账号名orID。
            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
            mask.show()
            ChainObjectManager.sharedChainObjectManager().queryAccountData(str_authority).then {
                mask.dismiss()
                val accountData = it as? JSONObject
                if (accountData != null && accountData.has("id") && accountData.has("name")) {
                    val new_oid = accountData.getString("id")
                    val account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
                    if (account.getString("id") == new_oid) {
                        showToast(resources.getString(R.string.kVcPermissionAddOneDontTipsCantAddSelf))
                    } else {
                        onAddOneDone(new_oid, accountData.getString("name"), true, i_threshold)
                    }
                } else {
                    showToast(resources.getString(R.string.kVcPermissionAddOneDoneTipsInvalidAuthority))
                }
                return@then null
            }
        }
    }

    /**
     *  (private) 完成添加
     */
    private fun onAddOneDone(key: String, name: String, isaccount: Boolean, threshold: Int) {
        _result_promise.resolve(JSONObject().apply {
            put("key", key)
            put("name", name)
            put("isaccount", isaccount)
            put("threshold", threshold)
        })
        finish()
    }
}
