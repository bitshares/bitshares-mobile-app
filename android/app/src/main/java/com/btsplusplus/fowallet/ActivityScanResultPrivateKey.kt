package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_scan_result_private_key.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityScanResultPrivateKey : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_scan_result_private_key)

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        val args = btspp_args_as_JSONObject()
        val privateKey = args.getString("privateKey")
        val publicKey = args.getString("publicKey")
        val full_account_data = args.getJSONObject("fullAccountData")
        val account_data = full_account_data.getJSONObject("account")

        //  获取公钥类型
        val priKeyTypeArray = JSONArray()
        val owner_key_auths = account_data.getJSONObject("owner").optJSONArray("key_auths")
        if (owner_key_auths != null && owner_key_auths.length() > 0) {
            for (pair in owner_key_auths.forin<JSONArray>()) {
                assert(pair!!.length() == 2)
                val key = pair.getString(0)
                if (key == publicKey) {
                    priKeyTypeArray.put(resources.getString(R.string.kVcScanResultPriKeyTypeOwner))
                    break
                }
            }
        }
        val active_key_auths = account_data.getJSONObject("active").optJSONArray("key_auths")
        if (active_key_auths != null && active_key_auths.length() > 0) {
            for (pair in active_key_auths.forin<JSONArray>()) {
                assert(pair!!.length() == 2)
                val key = pair.getString(0)
                if (key == publicKey) {
                    priKeyTypeArray.put(resources.getString(R.string.kVcScanResultPriKeyTypeActive))
                    break
                }
            }
        }
        val memo_key = account_data.optJSONObject("options")?.optString("memo_key", null)
        if (memo_key != null && memo_key == publicKey) {
            priKeyTypeArray.put(resources.getString(R.string.kVcScanResultPriKeyTypeMemo))
        }
        assert(priKeyTypeArray.length() > 0)

        //  初始化ID、名字、类型
        findViewById<TextView>(R.id.txt_account_id).text = account_data.getString("id")
        findViewById<TextView>(R.id.txt_account_name).text = account_data.getString("name")
        findViewById<TextView>(R.id.txt_private_key_type).let {
            it.text = priKeyTypeArray.toList<String>().joinToString(" ")
        }

        //  初始化钱包密码（可选）
        val bNeedWalletPassword = _needWalletPasswordField()
        if (bNeedWalletPassword) {
            lay_wallet_password.visibility = View.VISIBLE
            //  交易密码 tip
            findViewById<ImageView>(R.id.tip_password).setOnClickListener { UtilsAlert.showMessageBox(this, resources.getString(R.string.kLoginRegTipsWalletPasswordFormat)) }
        } else {
            lay_wallet_password.visibility = View.GONE
        }

        //  初始化导入按钮文字
        val btn_import = findViewById<Button>(R.id.button_import_private_key)
        if (WalletManager.sharedWalletManager().isPasswordMode()) {
            btn_import.text = resources.getString(R.string.kVcScanResultPriKeyBtnCreateAndImport)
        } else {
            btn_import.text = resources.getString(R.string.kVcScanResultPriKeyBtnImportNow)
        }

        //  事件 - 返回
        layout_back_from_scan_result_private_key.setOnClickListener { finish() }

        //  事件 - 导入
        btn_import.setOnClickListener {
            val trade_password = if (bNeedWalletPassword) findViewById<EditText>(R.id.tf_password).text.toString().trim() else null
            _onImportClicked(full_account_data, publicKey, privateKey, trade_password)
        }
    }

    /**
     * (private) 点击导入按钮
     */
    private fun _onImportClicked(full_account_data: JSONObject, pubKey: String, priKey: String, trade_passowrd: String?) {
        val walletMgr = WalletManager.sharedWalletManager()
        val mode = walletMgr.getWalletMode()
        when (mode) {
            AppCacheManager.EWalletMode.kwmNoWallet.value -> {
                assert(trade_passowrd != null)
                val status = walletMgr.createNewWallet(this, full_account_data, JSONObject().apply { put(pubKey, priKey) }, false,
                        null, trade_passowrd!!, AppCacheManager.EWalletMode.kwmPrivateKeyWithWallet, "private key with wallet")
                if (status == EImportToWalletStatus.eitws_no_permission) {
                    showToast(resources.getString(R.string.kLoginSubmitTipsPrivateKeyIncorrect))
                } else if (status == EImportToWalletStatus.eitws_partial_permission) {
                    showToast(resources.getString(R.string.kLoginSubmitTipsPermissionNotEnoughAndCannotBeImported))
                } else if (status == EImportToWalletStatus.eitws_ok) {
                    showToast(resources.getString(R.string.kWalletImportSuccess))
                    finish()
                } else {
                    assert(false)
                }
            }
            AppCacheManager.EWalletMode.kwmPasswordOnlyMode.value -> {
                guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {
                        val current_account_data = walletMgr.getWalletAccountInfo()!!

                        val status = walletMgr.createNewWallet(this, current_account_data, JSONObject().apply { put(pubKey, priKey) }, true,
                                jsonArrayfrom(full_account_data.getJSONObject("account").getString("name")),
                                trade_passowrd!!, AppCacheManager.EWalletMode.kwmPasswordWithWallet, "scan upgrade password+wallet")

                        assert(status == EImportToWalletStatus.eitws_ok)
                        showToast(resources.getString(R.string.kWalletImportSuccess))
                        finish()
                    }
                }
            }
            else -> {
                //  钱包模式 or 交易密码模式，直接解锁然后导入私钥匙。
                guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {
                        val pAppCache = AppCacheManager.sharedAppCacheManager()

                        //  导入账号到现有钱包BIN文件中
                        val full_wallet_bin = walletMgr.walletBinImportAccount(full_account_data.getJSONObject("account").getString("name"), jsonArrayfrom(priKey))!!
                        pAppCache.apply {
                            updateWalletBin(full_wallet_bin)
                            autoBackupWalletToWebdir(false)
                        }
                        //  重新解锁（即刷新解锁后的账号信息）。
                        val unlockInfos = walletMgr.reUnlock(this)
                        assert(unlockInfos.getBoolean("unlockSuccess"))

                        //  REMARK：导入到现有钱包不用判断导入结果，总是成功。
                        showToast(resources.getString(R.string.kWalletImportSuccess))
                        finish()
                    }
                }
            }
        }
    }

    /**
     *  (private) 是否需要钱包密码字段
     */
    private fun _needWalletPasswordField(): Boolean {
        val mode = WalletManager.sharedWalletManager().getWalletMode()
        return (mode == AppCacheManager.EWalletMode.kwmNoWallet.value || mode == AppCacheManager.EWalletMode.kwmPasswordOnlyMode.value)
    }

}
