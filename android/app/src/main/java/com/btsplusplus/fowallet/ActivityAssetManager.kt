package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_asset_manager.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityAssetManager : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_manager)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  事件 - 创建资产
        button_add_from_assets_manager.setOnClickListener {
            val result_promise = Promise()
            goTo(ActivityAssetCreateOrEdit::class.java, true, args = JSONObject().apply {
                put("kTitle", resources.getString(R.string.kVcTitleAssetOpCreate))
                put("result_promise", result_promise)
            })
            result_promise.then { dirty ->
                //  刷新UI
                if (dirty != null && dirty as Boolean) {
                    queryMyIssuedAssets()
                }
            }
        }

        //  事件 - 返回
        layout_back_from_assets_manager.setOnClickListener { finish() }

        //  查询
        queryMyIssuedAssets()
    }

    private fun queryMyIssuedAssets() {
        val account_name = WalletManager.sharedWalletManager().getWalletAccountName()!!

        //  TODO:4.0 limit config
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
        chainMgr.queryAssetsByIssuer(account_name, "1.${EBitsharesObjectType.ebot_asset.value}.0", 100).then {
            val issuerHash = JSONObject()
            val bitasset_data_id_list = JSONArray()
            val dynamic_asset_data_id_list = JSONArray()

            val data_array = (it as? JSONArray) ?: JSONArray()
            for (asset in data_array.forin<JSONObject>()) {
                issuerHash.put(asset!!.getString("issuer"), true)
                val bitasset_data_id = asset.optString("bitasset_data_id")
                if (bitasset_data_id.isNotEmpty()) {
                    bitasset_data_id_list.put(bitasset_data_id)
                }
                val dynamic_asset_data_id = asset.getString("dynamic_asset_data_id")
                dynamic_asset_data_id_list.put(dynamic_asset_data_id)
            }

            //  全部都查询都忽略缓存
            bitasset_data_id_list.putAll(issuerHash.keys().toJSONArray())
            val p1 = chainMgr.queryAllGrapheneObjectsSkipCache(bitasset_data_id_list)
            val p2 = chainMgr.queryAllGrapheneObjectsSkipCache(dynamic_asset_data_id_list)
            return@then Promise.all(p1, p2).then {
                mask.dismiss()
                onQueryMyIssuedAssetsResponsed(data_array)
                return@then null
            }
        }.catch { err ->
            mask.dismiss()
            showGrapheneError(err)
        }
    }

    private fun onQueryMyIssuedAssetsResponsed(data_array: JSONArray) {
        drawUI(data_array)
    }

    private fun drawUI(data_array: JSONArray) {
        lay_cell_container.let { layout ->
            layout.removeAllViews()
            if (data_array.length() > 0) {
                data_array.forEach<JSONObject> {
                    val asset = it!!
                    val v = ViewAssetCell(this, asset)
                    v.setOnClickListener { onCellClicked(asset) }
                    layout.addView(v)
                }
            } else {
                layout.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kVcAssetMgrEmptyList)))
            }
        }
    }

    private fun onCellClicked(asset: JSONObject) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val bitasset_data_id = asset.optString("bitasset_data_id")
        var bitasset_data: JSONObject? = null
        if (bitasset_data_id.isNotEmpty()) {
            bitasset_data = chainMgr.getChainObjectByID(bitasset_data_id)
        }

        val self = this
        val list = JSONArray().apply {
            //  TODO:7.0 暂时去掉
//            put(JSONObject().apply {
//                put("type", EBitsharesAssetOpKind.ebaok_view)
//                put("title", self.resources.getString(R.string.kVcAssetMgrCellActionViewDetail))
//            })
            put(JSONObject().apply {
                put("type", EBitsharesAssetOpKind.ebaok_edit)
                put("title", self.resources.getString(R.string.kVcAssetMgrCellActionUpdateAsset))
            })
            if (bitasset_data != null) {
                put(JSONObject().apply {
                    put("type", EBitsharesAssetOpKind.ebaok_update_bitasset)
                    put("title", self.resources.getString(R.string.kVcAssetMgrCellActionUpdateBitasset))
                })
                //  允许发行人强制清算
                if (ModelUtils.assetCanGlobalSettle(asset)) {
                    put(JSONObject().apply {
                        put("type", EBitsharesAssetOpKind.ebaok_global_settle)
                        put("title", self.resources.getString(R.string.kVcAssetMgrCellActionGlobalSettle))
                    })
                }
            } else {
                put(JSONObject().apply {
                    put("type", EBitsharesAssetOpKind.ebaok_issue)
                    put("title", self.resources.getString(R.string.kVcAssetMgrCellActionIssueAsset))
                })
            }
            //  非核心资产，都可以提取手续费池。
            if (asset.getString("id") != chainMgr.grapheneCoreAssetID) {
                put(JSONObject().apply {
                    put("type", EBitsharesAssetOpKind.ebaok_claim_pool)
                    put("title", self.resources.getString(R.string.kVcAssetMgrCellActionClaimFeePool))
                })
            }
            //  提取资产交易手续费
            put(JSONObject().apply {
                put("type", EBitsharesAssetOpKind.ebaok_claim_fees)
                put("title", self.resources.getString(R.string.kVcAssetMgrCellActionClaimMarketFees))
            })
        }

        ViewSelector.show(this, "", list, key = "title") { index: Int, _: String ->
            val item = list.getJSONObject(index)
            when (item.get("type") as EBitsharesAssetOpKind) {
                EBitsharesAssetOpKind.ebaok_view -> {
                    //  TODO:5.0暂不支持
                }
                EBitsharesAssetOpKind.ebaok_edit -> {
                    //  查询黑白名单中各种ID依赖。编辑黑白名单列表需要显示名称。
                    val options = asset.getJSONObject("options")
                    val ids_hash = JSONObject()
                    for (oid in options.getJSONArray("whitelist_authorities").forin<String>()) {
                        ids_hash.put(oid, true)
                    }
                    for (oid in options.getJSONArray("blacklist_authorities").forin<String>()) {
                        ids_hash.put(oid, true)
                    }
                    for (oid in options.getJSONArray("whitelist_markets").forin<String>()) {
                        ids_hash.put(oid, true)
                    }
                    for (oid in options.getJSONArray("blacklist_markets").forin<String>()) {
                        ids_hash.put(oid, true)
                    }
                    VcUtils.simpleRequest(this, chainMgr.queryAllGrapheneObjects(ids_hash.keys().toJSONArray())) {
                        val result_promise = Promise()
                        goTo(ActivityAssetCreateOrEdit::class.java, true, args = JSONObject().apply {
                            put("kEditAsset", asset)
                            put("kTitle", self.resources.getString(R.string.kVcTitleAssetOpUpdateBasic))
                            put("result_promise", result_promise)
                        })
                        result_promise.then { dirty ->
                            //  刷新UI
                            if (dirty != null && dirty as Boolean) {
                                queryMyIssuedAssets()
                            }
                        }
                    }
                }
                EBitsharesAssetOpKind.ebaok_update_bitasset -> {
                    if (ModelUtils.assetHasGlobalSettle(bitasset_data!!)) {
                        showToast(resources.getString(R.string.kVcAssetMgrActionTipsAlreadyGsCannotUpdateBitasset))
                        return@show
                    }
                    //  查询背书资产名称依赖
                    VcUtils.guardGrapheneObjectDependence(this, bitasset_data!!.getJSONObject("options").getString("short_backing_asset")) {
                        val result_promise = Promise()
                        goTo(ActivityAssetCreateOrEdit::class.java, true, args = JSONObject().apply {
                            put("kEditAsset", asset)
                            put("kEditBitAsset", bitasset_data)
                            put("kTitle", self.resources.getString(R.string.kVcTitleAssetOpUpdateBitasset))
                            put("result_promise", result_promise)
                        })
                        result_promise.then { dirty ->
                            //  刷新UI
                            if (dirty != null && dirty as Boolean) {
                                queryMyIssuedAssets()
                            }
                        }
                    }
                }
                EBitsharesAssetOpKind.ebaok_issue -> {
                    val result_promise = Promise()
                    goTo(ActivityAssetOpissue::class.java, true, args = JSONObject().apply {
                        put("kAsset", asset)
                        put("kDynamicAssetData", chainMgr.getChainObjectByID(asset.getString("dynamic_asset_data_id")))
                        put("kTitle", self.resources.getString(R.string.kVcTitleAssetOpIssue))
                        put("result_promise", result_promise)
                    })
                    result_promise.then { dirty ->
                        //  刷新UI
                        if (dirty != null && dirty as Boolean) {
                            queryMyIssuedAssets()
                        }
                    }
                }
                EBitsharesAssetOpKind.ebaok_global_settle -> {
                    if (ModelUtils.assetHasGlobalSettle(bitasset_data!!)) {
                        showToast(resources.getString(R.string.kVcAssetMgrActionTipsAlreadyGsCannotGsAgain))
                        return@show
                    }
                    //  查询背书资产名称依赖
                    VcUtils.guardGrapheneObjectDependence(this, bitasset_data.getJSONObject("options").getString("short_backing_asset")) {
                        val result_promise = Promise()
                        goTo(ActivityAssetOpGlobalSettle::class.java, true, args = JSONObject().apply {
                            put("current_asset", asset)
                            put("bitasset_data", bitasset_data)
                            put("result_promise", result_promise)
                        })
                        result_promise.then { dirty ->
                            //  刷新UI
                            if (dirty != null && dirty as Boolean) {
                                queryMyIssuedAssets()
                            }
                        }
                    }
                }
                EBitsharesAssetOpKind.ebaok_claim_pool -> {
                    VcUtils.guardGrapheneObjectDependence(this, asset.getString("dynamic_asset_data_id")) {
                        val result_promise = Promise()
                        goTo(ActivityAssetOpCommon::class.java, true, args = JSONObject().apply {
                            put("current_asset", asset)
                            put("full_account_data", null)
                            put("op_extra_args", JSONObject().apply {
                                put("kOpType", EBitsharesAssetOpKind.ebaok_claim_pool)
                                put("kMsgTips", self.resources.getString(R.string.kVcAssetOpClaimFeePoolUiTips))
                                put("kMsgAmountPlaceholder", self.resources.getString(R.string.kVcAssetOpClaimFeePoolCellPlaceholderAmount))
                                put("kMsgBtnName", self.resources.getString(R.string.kVcAssetOpClaimFeePoolBtnName))
                                put("kMsgSubmitInputValidAmount", self.resources.getString(R.string.kVcAssetOpClaimFeePoolSubmitTipsPleaseInputAmount))
                                put("kMsgSubmitOK", self.resources.getString(R.string.kVcAssetOpClaimFeePoolSubmitTipOK))
                            })
                            put("result_promise", result_promise)
                        })
                        result_promise.then { dirty ->
                            //  刷新UI
                            if (dirty != null && dirty as Boolean) {
                                queryMyIssuedAssets()
                            }
                        }
                    }
                }
                EBitsharesAssetOpKind.ebaok_claim_fees -> {
                    VcUtils.guardGrapheneObjectDependence(this, asset.getString("dynamic_asset_data_id")) {
                        val result_promise = Promise()
                        goTo(ActivityAssetOpCommon::class.java, true, args = JSONObject().apply {
                            put("current_asset", asset)
                            put("full_account_data", null)
                            put("op_extra_args", JSONObject().apply {
                                put("kOpType", EBitsharesAssetOpKind.ebaok_claim_fees)
                                put("kMsgTips", self.resources.getString(R.string.kVcAssetOpClaimMarketFeesUiTips))
                                put("kMsgAmountPlaceholder", self.resources.getString(R.string.kVcAssetOpClaimMarketFeesCellPlaceholderAmount))
                                put("kMsgBtnName", self.resources.getString(R.string.kVcAssetOpClaimMarketFeesBtnName))
                                put("kMsgSubmitInputValidAmount", self.resources.getString(R.string.kVcAssetOpClaimMarketFeesSubmitTipsPleaseInputAmount))
                                put("kMsgSubmitOK", self.resources.getString(R.string.kVcAssetOpClaimMarketFeesSubmitTipOK))
                            })
                            put("result_promise", result_promise)
                        })
                        result_promise.then { dirty ->
                            //  刷新UI
                            if (dirty != null && dirty as Boolean) {
                                queryMyIssuedAssets()
                            }
                        }
                    }
                }
            }
        }

    }
}
