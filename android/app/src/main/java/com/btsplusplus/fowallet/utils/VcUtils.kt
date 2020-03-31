package com.btsplusplus.fowallet.utils

import android.app.Activity
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
    }
}
