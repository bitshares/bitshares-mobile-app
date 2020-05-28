package com.btsplusplus.fowallet.utils

import android.app.Activity
import android.widget.ImageView
import bitshares.*
import com.btsplusplus.fowallet.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject

class VcUtils {

    companion object {

        /**
         *  (public) 转到问号QA提示页面。
         */
        fun gotoQaView(ctx: Activity, anchor_name: String, title: String) {
            //  [统计]
            btsppLogCustom("qa_tip_click", JSONObject().apply {
                put("qa", anchor_name)
            })
            ctx.goToWebView(title, "https://btspp.io/${ctx.resources.getString(R.string.qaHtmlFileName)}#$anchor_name")
        }

        /**
         *  确保依赖
         */
        fun guardGrapheneObjectDependence(ctx: Activity, object_ids: Any, body: () -> Unit) {
            val ary: JSONArray
            if (object_ids is JSONArray) {
                ary = object_ids
            } else {
                ary = jsonArrayfrom(object_ids)
            }
            simpleRequest(ctx, ChainObjectManager.sharedChainObjectManager().queryAllGrapheneObjects(ary)) {
                body()
            }
        }

        /**
         *  (public) 封装基本的请求操作。
         */
        fun simpleRequest(ctx: Activity, request: Promise, callback: (data: Any?) -> Unit) {
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx).apply { show() }
            request.then {
                mask.dismiss()
                callback(it)
                return@then null
            }.catch {
                mask.dismiss()
                ctx.showToast(R.string.tip_network_error.xmlstring(ctx))
            }
        }

        /**
         *  (public) 判断两个资产哪个作为base资产，返回base资产的symbol。
         */
        fun calcBaseAsset(asset_symbol01: String, asset_symbol02: String): String {
            val priorityHash = ChainObjectManager.sharedChainObjectManager().genAssetBasePriorityHash()
            val priority01 = priorityHash.optInt(asset_symbol01, 0)
            val priority02 = priorityHash.optInt(asset_symbol02, 0)
            if (priority01 > priority02) {
                return asset_symbol01
            } else {
                return asset_symbol02
            }
        }

        /**
         *  (public) 处理响应 - 检测APP版本信息数据返回。有新版本返回 YES，否新版本返回 NO。
         */
        fun processCheckAppVersionResponsed(ctx: Activity, pConfig: JSONObject?, remind_later_callback: (() -> Unit)?): Boolean {
            if (pConfig != null) {
                val pNativeVersion = Utils.appVersionName()
                val pNewestVersion = pConfig.optString("version", "")
                if (pNewestVersion != "") {
                    val ret = Utils.compareVersion(pNewestVersion, pNativeVersion)
                    if (ret > 0) {
                        //  有更新
                        var message = pConfig.optString(ctx.resources.getString(R.string.launchTipVersionKey), "")
                        if (message == "") {
                            message = String.format(ctx.resources.getString(R.string.launchTipDefaultNewVersion), pNewestVersion)
                        }
                        _showAppUpdateWindow(ctx, message, pConfig.getString("appURL"), pConfig.getString("force").toInt() != 0, remind_later_callback)
                        //  有新版本
                        return true
                    }
                }
            }
            //  无新版本
            return false
        }

        /**
         *  (private) 询问 - 是否更新版本
         */
        private fun _showAppUpdateWindow(ctx: Activity, message: String, url: String, forceUpdate: Boolean, remind_later_callback: (() -> Unit)?) {
            var btn_cancel: String? = null
            if (!forceUpdate) {
                btn_cancel = ctx.resources.getString(R.string.kRemindMeLatter)
            }
            UtilsAlert.showMessageConfirm(ctx, ctx.resources.getString(R.string.kWarmTips), message, btn_ok = ctx.resources.getString(R.string.kUpgradeNow), btn_cancel = btn_cancel).then {
                if (it != null && it as Boolean) {
                    //  立即升级
                    ctx.openURL(url)
                } else {
                    //  稍后提醒
                    if (remind_later_callback != null) {
                        remind_later_callback()
                    }
                }
            }
        }

        /**
         *  (public) 生成邀请链接
         */
        fun genShareLink(ctx: Activity, containWelcomeMessage: Boolean): String {
            val walletMgr = WalletManager.sharedWalletManager()
            var value = String.format("https://faucet.btspp.io/?lang=%s", ctx.resources.getString(R.string.kShareLinkPageDefaultLang))
            if (walletMgr.isWalletExist()) {
                value = String.format("%s&r=%s", value, walletMgr.getWalletAccountName()!!)
            }
            if (containWelcomeMessage) {
                value = String.format("%s\n%s", ctx.resources.getString(R.string.kShareWelcomeMessage), value)
            }
            return value
        }

        /**
         *  (public) 处理导入隐私账户。
         */
        fun processImportBlindAccount(ctx: Activity, str_alias_name: String, str_password: String, success_callback: ((blind_account: JSONObject) -> Unit)?) {
            if (str_alias_name.isEmpty()) {
                ctx.showToast(ctx.resources.getString(R.string.kVcStTipErrPleaseInputAliasName))
                return
            }

            if (str_password.isEmpty() || !WalletManager.isValidStealthTransferBrainKey(str_password, kAppBlindAccountBrainKeyCheckSumPrefix)) {
                ctx.showToast(ctx.resources.getString(R.string.kVcStTipErrPleaseInputBlindAccountBrainKey))
                return
            }

            //  开始导入
            val hdk = HDWallet.fromMnemonic(str_password)
            val main_key = hdk.deriveBitshares(EHDBitsharesPermissionType.ehdbpt_stealth_mainkey)
            val wif_main_pri_key = main_key.toWifPrivateKey()
            val wif_main_pub_key = OrgUtils.genBtsAddressFromWifPrivateKey(wif_main_pri_key)!!

            val blind_account = JSONObject().apply {
                put("public_key", wif_main_pub_key)
                put("alias_name", str_alias_name)
                put("parent_key", "")
            }

            val walletMgr = WalletManager.sharedWalletManager()
            assert(walletMgr.isWalletExist() && !walletMgr.isPasswordMode())

            //  解锁钱包
            ctx.guardWalletUnlocked(false) { unlocked ->
                if (unlocked) {
                    //  隐私交易主地址导入钱包
                    val full_wallet_bin = walletMgr.walletBinImportAccount(null, jsonArrayfrom(wif_main_pri_key))!!
                    AppCacheManager.sharedAppCacheManager().apply {
                        appendBlindAccount(blind_account, auto_save = false)
                        updateWalletBin(full_wallet_bin)
                        autoBackupWalletToWebdir(false)
                    }

                    //  重新解锁（即刷新解锁后的账号信息）。
                    val unlockInfos = walletMgr.reUnlock(ctx)
                    assert(unlockInfos.getBoolean("unlockSuccess"))

                    //  导入成功
                    if (success_callback != null) {
                        success_callback(blind_account)
                    }
                }
            }
        }

        /**
         *  (public) 处理交易对状态变更，收藏 or 取消收藏。变更成功返回 YES，否则返回 NO。
         */
        fun processMyFavPairStateChanged(ctx: Activity, quote: JSONObject, base: JSONObject, associated_view: ImageView?): Boolean {
            val pAppCache = AppCacheManager.sharedAppCacheManager()

            val quote_id = quote.getString("id")
            val base_id = base.getString("id")

            if (pAppCache.is_fav_market(quote_id, base_id)) {
                //  删除的情况
                pAppCache.remove_fav_markets(quote_id, base_id)
                associated_view?.setColorFilter(ctx.resources.getColor(R.color.theme01_textColorGray))
                ctx.showToast(ctx.resources.getString(R.string.kTipsAddFavDelete))
                //  [统计]
                btsppLogCustom("event_market_remove_fav", jsonObjectfromKVS("base", base_id, "quote", quote_id))
            } else {
                //  添加的情况，如果是自定义交易对，则需要判断是否达到上限，收藏交易对则不用额外处理。
                val chainMgr = ChainObjectManager.sharedChainObjectManager()

                //  自定义交易对判断
                if (!chainMgr.isDefaultPair(quote, base)) {
                    val max_custom_pair_num = chainMgr.getDefaultParameters().getInt("max_custom_pair_num")
                    var n_custom = 0
                    val favhash = pAppCache.get_all_fav_markets()
                    for (key in favhash.keys()) {
                        val favitem = favhash.getJSONObject(key)
                        val q = chainMgr.getChainObjectByID(favitem.getString("quote"))
                        val b = chainMgr.getChainObjectByID(favitem.getString("base"))
                        if (!chainMgr.isDefaultPair(q, b)) {
                            n_custom += 1
                        }
                    }
                    if (n_custom >= max_custom_pair_num) {
                        ctx.showToast(String.format(ctx.resources.getString(R.string.kSearchTipsMaxCustomParisNumber), max_custom_pair_num.toString()))
                        return false
                    }
                }

                //  不限制：添加收藏。
                pAppCache.set_fav_markets(quote_id, base_id)
                associated_view?.setColorFilter(ctx.resources.getColor(R.color.theme01_textColorHighlight))
                ctx.showToast(ctx.resources.getString(R.string.kTipsAddFavSuccess))
                //  [统计]
                btsppLogCustom("event_market_add_fav", jsonObjectfromKVS("base", base_id, "quote", quote_id))
            }

            //  保存
            pAppCache.saveFavMarketsToFile()

            //  标记：自选列表需要更新
            TempManager.sharedTempManager().favoritesMarketDirty = true
            return true
        }
    }
}
