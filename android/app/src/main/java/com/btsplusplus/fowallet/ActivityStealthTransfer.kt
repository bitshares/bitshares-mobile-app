package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.Promise
import bitshares.jsonArrayfrom
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_stealth_transfer.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityStealthTransfer : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_stealth_transfer)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  返回事件
        layout_back_from_stealth_transfer.setOnClickListener { finish() }

        //  点击跳转事件
        layout_account_manage_from_stealth_transfer.setOnClickListener { OnAccountManageClicked() }
        layout_my_receipt_from_stealth_transfer.setOnClickListener { onMyReceiptClicked() }
        layout_transfer_to_blind_from_stealth_transfer.setOnClickListener { onTransferToBlindClicked() }
        layout_transfer_from_blind_from_stealth_transfer.setOnClickListener { onTransferFromBlindClicked() }
        layout_blind_transfer_from_stealth_transfer.setOnClickListener { onBlindTransferClicked() }

        //  设置图标颜色
        img_icon_blind_accounts.setColorFilter(resources.getColor(R.color.theme01_textColorNormal))
        img_icon_blind_balances.setColorFilter(resources.getColor(R.color.theme01_textColorNormal))
        img_icon_transfer_to_blind.setColorFilter(resources.getColor(R.color.theme01_textColorNormal))
        img_icon_transfer_from_blind.setColorFilter(resources.getColor(R.color.theme01_textColorNormal))
        img_icon_blind_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorNormal))

        //  设置箭头颜色
        iv_account_manage_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        iv_my_receipt_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        iv_transfer_to_blind_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        iv_transfer_from_blind_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        iv_blind_transfer_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
    }

    private fun OnAccountManageClicked() {
        val self = this
        goTo(ActivityBlindAccounts::class.java, true, args = JSONObject().apply {
            put("title", self.resources.getString(R.string.kVcTitleBlindAccountsMgr))
        })
    }

    private fun onMyReceiptClicked() {
        goTo(ActivityBlindBalance::class.java, true)
    }

    private fun onTransferToBlindClicked() {
        //  REMARK：默认隐私转账资产为 CORE 资产。
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val core_asset_id = chainMgr.grapheneCoreAssetID
        val p1 = get_full_account_data_and_asset_hash(WalletManager.sharedWalletManager().getWalletAccountName()!!)
        val p2 = chainMgr.queryAllGrapheneObjects(jsonArrayfrom(core_asset_id))
        VcUtils.simpleRequest(this, Promise.all(p1, p2)) {
            val data_array = it as JSONArray
            val full_account_data = data_array.getJSONObject(0)
            val core = chainMgr.getChainObjectByID(core_asset_id)
            goTo(ActivityTransferToBlind::class.java, true, args = JSONObject().apply {
                put("core_asset", core)
                put("full_account_data", full_account_data)
            })
        }
    }

    private fun onTransferFromBlindClicked() {
        goTo(ActivityTransferFromBlind::class.java, true, args = JSONObject())
    }

    private fun onBlindTransferClicked() {
        goTo(ActivityBlindTransfer::class.java, true, args = JSONObject())
    }


}
