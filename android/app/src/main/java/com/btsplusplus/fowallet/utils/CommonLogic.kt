package com.btsplusplus.fowallet.utils

import android.app.Activity
import bitshares.*
import com.btsplusplus.fowallet.R
import com.btsplusplus.fowallet.ViewMask
import com.btsplusplus.fowallet.showGrapheneError
import com.btsplusplus.fowallet.showToast
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject

class CommonLogic {

    companion object {

        /**
         * 根据私钥登录（导入）区块链账号。
         */
        fun loginWithKeyHashs(ctx: Activity, pub_pri_keys_hash: JSONObject, checkActivePermission: Boolean, trade_password: String,
                              login_mode: Int, login_desc: String,
                              errMsgInvalidPrivateKey: String, errMsgActivePermissionNotEnough: String,
                              result_promise: Promise?) {
            assert(pub_pri_keys_hash.length() > 0)

            val chainMgr = ChainObjectManager.sharedChainObjectManager()

            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
            mask.show()

            chainMgr.queryAccountDataHashFromKeys(pub_pri_keys_hash.keys().toJSONArray()).then {
                val account_data_hash = it as JSONObject
                if (account_data_hash.length() <= 0) {
                    mask.dismiss()
                    ctx.showToast(errMsgInvalidPrivateKey)
                    return@then null
                }
                val account_data_list = account_data_hash.values()
                if (account_data_list.length() >= 2) {
                    //  TODO:一个私钥关联多个账号的情况处理
                }
                //  默认选择第一个账号
                val account_data = account_data_list.getJSONObject(0)
                return@then chainMgr.queryFullAccountInfo(account_data.getString("id")).then {
                    mask.dismiss()
                    val full_data = it as? JSONObject
                    if (full_data == null) {
                        ctx.showToast(ctx.resources.getString(R.string.kLoginImportTipsQueryAccountFailed))
                        return@then null
                    }
                    val account = full_data.getJSONObject("account")
                    val accountName = account.getString("name")

                    //  正常私钥登录需要验证权限，导入到已有钱包则不用验证。
                    if (checkActivePermission) {
                        //  获取active权限数据
                        val account_active = account.getJSONObject("active")

                        //  检测权限是否足够签署需要active权限的交易。
                        val status = WalletManager.calcPermissionStatus(account_active, pub_pri_keys_hash)
                        if (status == EAccountPermissionStatus.EAPS_NO_PERMISSION) {
                            ctx.showToast(errMsgInvalidPrivateKey)
                            return@then null
                        }
                        if (status == EAccountPermissionStatus.EAPS_PARTIAL_PERMISSION) {
                            ctx.showToast(errMsgActivePermissionNotEnough)
                            return@then null
                        }
                    }

                    //  筛选账号 account 所有公钥对应的私钥。（即：有效私钥）
                    val account_all_pubkeys = WalletManager.getAllPublicKeyFromAccountData(account)
                    val valid_private_wif_keys = JSONArray()
                    pub_pri_keys_hash.keys().forEach { pubkey ->
                        if (account_all_pubkeys.has(pubkey)) {
                            valid_private_wif_keys.put(pub_pri_keys_hash.getString(pubkey))
                        }
                    }
                    assert(valid_private_wif_keys.length() > 0)

                    if (checkActivePermission) {
                        //  【正常登录】完整钱包模式
                        val full_wallet_bin = WalletManager.sharedWalletManager().genFullWalletData(ctx, accountName, valid_private_wif_keys, trade_password)
                        //  保存钱包信息
                        AppCacheManager.sharedAppCacheManager().setWalletInfo(AppCacheManager.EWalletMode.kwmPrivateKeyWithWallet.value, full_data, accountName, full_wallet_bin)
                        AppCacheManager.sharedAppCacheManager().autoBackupWalletToWebdir(false)
                        //  导入成功 用交易密码 直接解锁。
                        val unlockInfos = WalletManager.sharedWalletManager().unLock(trade_password, ctx)
                        assert(unlockInfos.getBoolean("unlockSuccess") && unlockInfos.optBoolean("haveActivePermission"))
                        //  [统计]
                        btsppLogCustom("loginEvent", jsonObjectfromKVS("mode", login_mode, "desc", login_desc))
                        //  返回 - 登录成功
                        ctx.showToast(ctx.resources.getString(R.string.kLoginTipsLoginOK))
                        ctx.finish()
                    } else {
                        //  【导入到已有钱包】
                        val full_wallet_bin = WalletManager.sharedWalletManager().walletBinImportAccount(accountName, valid_private_wif_keys)!!
                        AppCacheManager.sharedAppCacheManager().apply {
                            updateWalletBin(full_wallet_bin)
                            autoBackupWalletToWebdir(false)
                        }
                        //  重新解锁（即刷新解锁后的账号信息）。
                        val unlockInfos = WalletManager.sharedWalletManager().reUnlock(ctx)
                        assert(unlockInfos.getBoolean("unlockSuccess"))

                        //  返回 - 导入成功
                        ctx.showToast(R.string.kWalletImportSuccess.xmlstring(ctx))

                        //  处理结果
                        result_promise?.resolve(true)

                        ctx.finish()
                    }
                    return@then null
                }
            }.catch {
                mask.dismiss()
                ctx.showGrapheneError(it)
            }
        }

    }
}
