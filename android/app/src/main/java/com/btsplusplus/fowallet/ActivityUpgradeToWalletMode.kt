package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.EditText
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_upgrade_to_wallet_mode.*

class ActivityUpgradeToWalletMode : BtsppActivity() {

    private lateinit var _result_promise: Promise

    /**
     * 系统返回键
     */
    override fun onBackPressed() {
        onBackClicked(false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_upgrade_to_wallet_mode)

        setFullScreen()

        //  获取参数 / get params
        val args = btspp_args_as_JSONObject()
        _result_promise = args.get("result_promise") as Promise

        //  刷新UI
        refreshHeaderInfoUI()

        //  返回按钮事件
        layout_back_from_page_of_upgrade_to_wallet_model.setOnClickListener { onBackClicked(false) }

        //  帮助按钮事件
        tip_link_wallet_password_of_upgrade_to_wallet.setOnClickListener {
            UtilsAlert.showMessageBox(this, R.string.kLoginRegTipsWalletPasswordFormat.xmlstring(this))
        }

        //  创建钱包按钮事件
        button_create_wallet_of_upgrade_to_wallet.setOnClickListener { onSubmitClicked() }
    }

    override fun onBackClicked(success: Any?) {
        _result_promise.resolve(success)
        finish()
    }

    private fun onSubmitClicked() {
        val password = findViewById<EditText>(R.id.tf_password_of_upgrade_to_wallet).text.toString()
        val wallet_password = findViewById<EditText>(R.id.tf_wallet_password_of_upgrade_to_wallet).text.toString()

        if (password.isEmpty()) {
            showToast(resources.getString(R.string.kMsgPasswordCannotBeNull))
            return
        }

        if (!Utils.isValidBitsharesWalletPassword(wallet_password)) {
            showToast(R.string.kLoginSubmitTipsWalletPasswordFmtIncorrect.xmlstring(this))
            return
        }

        //  1、再次验证账号密码是否正确
        val full_account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
        val accountName = full_account_data.getJSONObject("account").getString("name")
        val walletMgr = WalletManager.sharedWalletManager()
        val currUnlockInfos = walletMgr.unLock(password, this)
        if (!(currUnlockInfos.getBoolean("unlockSuccess") && currUnlockInfos.optBoolean("haveActivePermission"))) {
            showToast(R.string.kLoginSubmitTipsAccountPasswordIncorrect.xmlstring(this))
            return
        }

        //  2、验证通过，开始创建钱包文件。
        val active_seed = "${accountName}active${password}"
        val active_private_wif = OrgUtils.genBtsWifPrivateKey(active_seed.utf8String())
        val owner_seed = "${accountName}owner${password}"
        val owner_private_wif = OrgUtils.genBtsWifPrivateKey(owner_seed.utf8String())
        val full_wallet_bin = walletMgr.genFullWalletData(this, accountName, jsonArrayfrom(active_private_wif, owner_private_wif), wallet_password)!!

        //  3、保存钱包信息
        AppCacheManager.sharedAppCacheManager().apply {
            setWalletInfo(AppCacheManager.EWalletMode.kwmPasswordWithWallet.value, full_account_data, accountName, full_wallet_bin)
            autoBackupWalletToWebdir(false)
        }

        //  4、导入成功 用钱包密码 直接解锁。
        val unlockInfos = walletMgr.unLock(wallet_password, this)
        assert(unlockInfos.getBoolean("unlockSuccess") && unlockInfos.optBoolean("haveActivePermission"))

        //  [统计]
        btsppLogCustom("convertEvent", jsonObjectfromKVS("desc", "password+wallet", "account", accountName))

        //  转换成功 - 关闭界面

        //  返回 - 创建钱包完毕。
        showToast(R.string.kLblTipsConvertToWalletModeDone.xmlstring(this))
        onBackClicked(true)
    }

    private fun refreshHeaderInfoUI() {
        val full_account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
        val account_data = full_account_data.getJSONObject("account")
        findViewById<TextView>(R.id.account_name_of_upgrade_to_wallet).text = account_data.getString("name")
        findViewById<TextView>(R.id.account_id_of_upgrade_to_wallet).text = "#${account_data.getString("id").split(".").last()}"
    }

}
