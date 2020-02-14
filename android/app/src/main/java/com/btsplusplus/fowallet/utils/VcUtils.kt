package com.btsplusplus.fowallet.utils

import android.app.Activity
import bitshares.Promise
import bitshares.btsppLogCustom
import bitshares.jsonArrayfrom
import bitshares.xmlstring
import com.btsplusplus.fowallet.R
import com.btsplusplus.fowallet.ViewMask
import com.btsplusplus.fowallet.goToWebView
import com.btsplusplus.fowallet.showToast
import com.fowallet.walletcore.bts.ChainObjectManager
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

    }
}
