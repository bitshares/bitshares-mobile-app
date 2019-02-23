package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.TextView
import bitshares.AppCacheManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_account_info.*

class ActivityAccountInfo : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_account_info)

        setFullScreen()

        //  初始化 设置备份按钮是否可见
        val hexwallet_bin = AppCacheManager.sharedAppCacheManager().getWalletInfo().optString("kFullWalletBin", "")
        if (hexwallet_bin == "") {
            button_backup_wallet.visibility = android.view.View.GONE
        } else {
            button_backup_wallet.visibility = android.view.View.VISIBLE
        }

        //  初始化UI信息
        val full_account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
        val account = full_account_data.getJSONObject("account")
        findViewById<TextView>(R.id.txt_account_id).text = account.getString("id")
        findViewById<TextView>(R.id.txt_account_name).text = account.getString("name")
        findViewById<TextView>(R.id.txt_referrer_name).text = full_account_data.getString("referrer_name")
        findViewById<TextView>(R.id.txt_registrar_name).text = full_account_data.getString("registrar_name")
        findViewById<TextView>(R.id.txt_lifetime_referrer_name).text = full_account_data.getString("lifetime_referrer_name")

        //  返回
        layout_back_from_account_detail.setOnClickListener {
            finish()
        }

        //  备份钱包
        button_backup_wallet.setOnClickListener {
            backupWallet()
        }

        //  注销
        button_logout.setOnClickListener {
            gotoLogout()
        }
    }

    private fun gotoLogout() {
        alerShowMessageConfirm(resources.getString(R.string.registerLoginPageWarmTip), resources.getString(R.string.registerLoginPageTipForLogout)).then {
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
        finish()
    }

    private fun backupWallet() {
        goTo(ActivityWalletBackup::class.java, true)
    }
}
