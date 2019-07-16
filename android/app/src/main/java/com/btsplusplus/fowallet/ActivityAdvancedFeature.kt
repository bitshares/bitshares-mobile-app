package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.EHtlcDeployMode
import bitshares.Promise
import bitshares.xmlstring
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_advanced_feature.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityAdvancedFeature : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_advanced_feature)

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  设置图标颜色
        val iconcolor = resources.getColor(R.color.theme01_textColorNormal)
        img_icon_preimage.setColorFilter(iconcolor)
        img_icon_hashcode.setColorFilter(iconcolor)

        //  点击事件
        layout_back_from_advanced_feature.setOnClickListener { finish() }
        layout_htlc_preimage_of_advanced_feature.setOnClickListener { onClickCreateHtlc(EHtlcDeployMode.EDM_PREIMAGE.value) }
        layout_htlc_hash_of_advanced_feature.setOnClickListener { onClickCreateHtlc(EHtlcDeployMode.EDM_HASHCODE.value) }
    }

    private fun onClickCreateHtlc(mode: Int) {
        if (mode == EHtlcDeployMode.EDM_HASHCODE.value) {
            ViewSelector.show(this, "", arrayOf(resources.getString(R.string.kVcHtlcMenuPassiveCreate), resources.getString(R.string.kVcHtlcMenuProactivelyCreate))) { index: Int, result: String ->
                val havePreimage = index == 1
                _gotoHtlcActivity(mode, havePreimage)
            }
        } else {
            _gotoHtlcActivity(mode, true)
        }
    }

    private fun _gotoHtlcActivity(mode: Int, havePreimage: Boolean) {
        guardWalletExist {
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
            mask.show()
            val p1 = get_full_account_data_and_asset_hash(WalletManager.sharedWalletManager().getWalletAccountName()!!)
            val p2 = ChainObjectManager.sharedChainObjectManager().queryFeeAssetListDynamicInfo()
            Promise.all(p1, p2).then {
                mask.dismiss()
                val data_array = it as JSONArray
                val send_data = JSONObject().apply {
                    put("full_userdata", data_array.getJSONObject(0))
                    put("mode", mode)
                    put("havePreimage", havePreimage)
                    put("ref_htlc", null)
                    put("ref_to", null)
                }
                goTo(ActivityCreateHtlcContract::class.java, true, args = send_data)
                return@then null
            }.catch {
                mask.dismiss()
                showToast(resources.getString(R.string.tip_network_error))
            }
        }
    }
}
