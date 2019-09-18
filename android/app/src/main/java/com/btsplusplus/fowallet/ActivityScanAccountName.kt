package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import bitshares.Promise
import bitshares.jsonObjectfromKVS
import bitshares.xmlstring
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_scan_account_name.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityScanAccountName : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_scan_account_name)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val account = btspp_args_as_JSONObject()

        val tv_account_id = findViewById<TextView>(R.id.txt_account_id)
        val tv_account_name = findViewById<TextView>(R.id.txt_account_name)
        val btn_transfer = findViewById<Button>(R.id.button_transfer)
        val btn_detail = findViewById<Button>(R.id.button_view_detail)

        tv_account_id.text = account.getString("id")
        tv_account_name.text = account.getString("name")

        //  返回
        layout_back_from_scan_result_account_name.setOnClickListener { finish() }

        //  转账
        btn_transfer.setOnClickListener { onGotoTransfer(account) }

        //  查看详情
        btn_detail.setOnClickListener { viewUserAssets(account.getString("name")) }
    }

    private fun onGotoTransfer(default_to: JSONObject) {
        guardWalletExist {
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
            mask.show()
            val p1 = get_full_account_data_and_asset_hash(WalletManager.sharedWalletManager().getWalletAccountName()!!)
            val p2 = ChainObjectManager.sharedChainObjectManager().queryFeeAssetListDynamicInfo()
            Promise.all(p1, p2).then {
                mask.dismiss()
                val data_array = it as JSONArray
                val full_userdata = data_array.getJSONObject(0)
                goTo(ActivityTransfer::class.java, true, args = jsonObjectfromKVS("full_account_data", full_userdata, "default_to", default_to))
                return@then null
            }.catch {
                mask.dismiss()
                showToast(resources.getString(R.string.tip_network_error))
            }
        }
    }

}
