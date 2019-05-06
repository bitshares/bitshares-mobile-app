package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_advanced_feature.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityAdvancedFeature : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_advanced_feature)

        //  获取参数
        // val full_userdata = TempManager.sharedTempManager().get_args_as_JSONArray()

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        layout_back_from_advanced_feature.setOnClickListener {
            finish()
        }

        layout_htlc_preimage_of_advanced_feature.setOnClickListener {
            onClickCreateHtlc(EHtlcDeployMode.EDM_PREIMAGE.value)
        }

        layout_htlc_hash_of_advanced_feature.setOnClickListener {
            onClickCreateHtlc(EHtlcDeployMode.EDM_HASHCODE.value)
        }
    }

    private fun onClickCreateHtlc(mode: Int){

        if (mode == EHtlcDeployMode.EDM_HASHCODE.value){
           ViewSelector.show(this,"", arrayOf("被动部署合约","主动部署合约")) { index: Int, result: String ->
               val havePreimage = index == 1
                _gotoHtlcActivity(mode, havePreimage)
            }
        } else {
            _gotoHtlcActivity(mode)
        }
    }

    private fun _gotoHtlcActivity(mode: Int, havePreimage: Boolean? = null){
        guardWalletExist {
            val mask = ViewMesk(R.string.kTipsBeRequesting.xmlstring(this), this)
            mask.show()
            val p1 = get_full_account_data_and_asset_hash(WalletManager.sharedWalletManager().getWalletAccountName()!!)
            var p2 = ChainObjectManager.sharedChainObjectManager().queryFeeAssetListDynamicInfo()
            Promise.all(p1, p2).then {
                mask.dismiss()
                val data_array = it as JSONArray
                val send_data = JSONObject()
                val full_userdata = data_array.getJSONObject(0)
                send_data.put("full_userdata",jsonArrayfrom(full_userdata))
                send_data.put("mode",mode)
                send_data.put("havePreimage",havePreimage)
                send_data.put("ref_htlc",null)
                send_data.put("ref_to",null)

                goTo(ActivityCreateHtlcContract::class.java, true, args = send_data)
                return@then null
            }.catch {
                mask.dismiss()
                showToast(resources.getString(R.string.tip_network_error))
            }
        }
    }
}
