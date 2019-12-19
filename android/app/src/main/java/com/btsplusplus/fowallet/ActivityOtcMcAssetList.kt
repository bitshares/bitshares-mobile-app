package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_otc_mc_asset_list.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityOtcMcAssetList : BtsppActivity() {

    private lateinit var _auth_info: JSONObject
    private lateinit var _merchant_detail: JSONObject
    private var _user_type = OtcManager.EOtcUserType.eout_normal_user

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_asset_list)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _auth_info = args.getJSONObject("auth_info")
        _merchant_detail = args.getJSONObject("merchant_detail")
        _user_type = args.get("user_type") as OtcManager.EOtcUserType

        layout_back_from_otc_mc_asset_list.setOnClickListener { finish() }

        //  查询
        queryOtcAssets()
    }


    private fun onQueryOtcAssetsResponsed(merchantAssetList: JSONArray?, chainAssets: JSONArray?, coreAssetBalance: JSONObject?) {
        val chain_asset_map = JSONObject()
        if (chainAssets != null) {
            for (asset in chainAssets.forin<JSONObject>()) {
                val symbol = asset!!.optString("symbol", null)
                if (symbol != null) {
                    chain_asset_map.put(symbol, asset)
                }
            }
        }

        val data_array = JSONArray()

        if (coreAssetBalance != null) {
            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            val core_asset = chain_asset_map.getJSONObject(chainMgr.grapheneCoreAssetID)
            val core_precision = core_asset.getInt("precision")
            val n_core_amount = bigDecimalfromAmount(coreAssetBalance.getString("amount"), core_precision)
            data_array.put(JSONObject().apply {
                put("available", n_core_amount.toPlainString())
                put("freeze", 0)
                put("fees", 0)
                put("kExtPrecision", core_precision)
                put("kExtChainAsset", core_asset)
            })
        }

        if (merchantAssetList != null && merchantAssetList.length() > 0) {
            for (item in merchantAssetList.forin<JSONObject>()) {
                val chain_asset = chain_asset_map.optJSONObject(item!!.getString("assetSymbol"))
                assert(chain_asset != null)
                //  OTC服务器数据错误则可能导致链上资产不存在。
                if (chain_asset != null) {
                    item.put("kExtPrecision", chain_asset.getInt("precision"))
                    item.put("kExtChainAsset", chain_asset)
                    data_array.put(item)
                }
            }
        }

        //  刷新
        refreshUI(data_array)
    }

    private fun queryOtcAssets() {
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        otc.queryMerchantOtcAsset(otc.getCurrentBtsAccount()).then {
            val responsed = it as? JSONObject
            val assetSymbolHash = JSONObject()
            val merchantAssetList = responsed?.optJSONArray("data")
            if (merchantAssetList != null && merchantAssetList.length() > 0) {
                for (item in merchantAssetList.forin<JSONObject>()) {
                    assetSymbolHash.put(item!!.getString("assetSymbol"), true)
                }
            }

            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            val containCoreAsset = assetSymbolHash.has(chainMgr.grapheneAssetSymbol)
            //  REMARK：自动把手续费资产CORE，加入列表。
            if (!containCoreAsset) {
                assetSymbolHash.put(chainMgr.grapheneAssetSymbol, true)
            }
            if (assetSymbolHash.length() > 0) {
                //  查询资产信息和个人账号余额信息
                chainMgr.queryAssetDataList(assetSymbolHash.keys().toJSONArray()).then {
                    val chain_assets = it as? JSONArray
                    if (!containCoreAsset) {
                        //  查询手续费CORE资产的链上余额
                        return@then chainMgr.queryAccountBalance(_merchant_detail.getString("otcAccount"), jsonArrayfrom(chainMgr.grapheneCoreAssetID)).then {
                            mask.dismiss()
                            val balance_data_array = it as? JSONArray
                            val core_balance_data = balance_data_array?.optJSONObject(0)
                            onQueryOtcAssetsResponsed(merchantAssetList, chain_assets, core_balance_data)
                            return@then null
                        }
                    } else {
                        mask.dismiss()
                        onQueryOtcAssetsResponsed(merchantAssetList, chain_assets, null)
                    }
                    return@then null
                }.catch {
                    mask.dismiss()
                    showToast(resources.getString(R.string.tip_network_error))
                    onQueryOtcAssetsResponsed(null, null, null)
                }
            } else {
                mask.dismiss()
                onQueryOtcAssetsResponsed(null, null, null)
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }
    }

    private fun refreshUI(data_array: JSONArray) {
        layout_asset_list_from_otc_mc_home.removeAllViews()
        if (data_array.length() == 0) {
            layout_asset_list_from_otc_mc_home.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kOtcMcAssetEmptyLabel)))
        } else {
            data_array.forEach<JSONObject> {
                val item = it!!
                val view = ViewOtcMcAssetCell(this, item) { transfer_in -> gotoOtcMcAssetTransfer(transfer_in, item, data_array) }
                layout_asset_list_from_otc_mc_home.addView(view)
                layout_asset_list_from_otc_mc_home.addView(ViewLine(this, 0.dp, 10.dp))
            }
        }
    }

    private fun gotoOtcMcAssetTransfer(transfer_in: Boolean, curr_merchant_asset: JSONObject, data_array: JSONArray) {
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(OtcManager.sharedOtcManager().getCurrentBtsAccount()).then {
            mask.dismiss()
            val full_data = it as JSONObject
            //  转到划转界面
            val result_promise = Promise()
            goTo(ActivityOtcMcAssetTransfer::class.java, true, args = JSONObject().apply {
                put("auth_info", _auth_info)
                put("user_type", _user_type)
                put("merchant_detail", _merchant_detail)
                put("asset_list", data_array)
                put("curr_merchant_asset", curr_merchant_asset)
                put("full_account_data", full_data)
                put("transfer_in", transfer_in)
                put("result_promise", result_promise)
            })
            result_promise.then { dirty ->
                //  刷新UI
                if (dirty != null && dirty as Boolean) {
                    queryOtcAssets()
                }
                return@then null
            }
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }
}
