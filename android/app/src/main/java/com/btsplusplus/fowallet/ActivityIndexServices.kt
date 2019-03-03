package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_index_services.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityIndexServices : BtsppActivity() {

    val REQUEST_CODE_QR_SCAN = 101

    /**
     * 重载 - 返回键按下
     */
    override fun onBackPressed() {
        goHome()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_index_services, navigationBarColor = R.color.theme01_tabBarColor)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 设置底部导航栏样式
        setBottomNavigationStyle(2)

        //  设置图标颜色
        val iconcolor = resources.getColor(R.color.theme01_textColorNormal)
        img_icon_transfer.setColorFilter(iconcolor)
        img_icon_account_search.setColorFilter(iconcolor)
        img_icon_rank.setColorFilter(iconcolor)
        img_icon_voting.setColorFilter(iconcolor)
        img_icon_feedprice.setColorFilter(iconcolor)
        img_icon_deposit_withdraw.setColorFilter(iconcolor)
        img_icon_game.setColorFilter(iconcolor)

        layout_account_query_from_services.setOnClickListener {
            TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
                last_activity.goTo(ActivityIndexServices::class.java, true, back = true)
                viewUserAssets(it.getString("name"))
            }
            goTo(ActivityAccountQueryBase::class.java, true)
        }

        layout_diya_ranking_from_services.setOnClickListener {
            goTo(ActivityMarginRanking::class.java, true)
        }

        layout_transfer_from_services.setOnClickListener {
            guardWalletExist {
                val mask = ViewMesk(R.string.nameRequesting.xmlstring(this), this)
                mask.show()
                val p1 = get_full_account_data_and_asset_hash(WalletManager.sharedWalletManager().getWalletAccountName()!!)
                var p2 = ChainObjectManager.sharedChainObjectManager().queryFeeAssetListDynamicInfo()
                Promise.all(p1, p2).then {
                    mask.dismiss()
                    val data_array = it as JSONArray
                    val full_userdata = data_array.getJSONObject(0)
                    goTo(ActivityTransfer::class.java, true, args = jsonArrayfrom(full_userdata))
                    return@then null
                }.catch {
                    mask.dismiss()
                    showToast(resources.getString(R.string.nameNetworkException))
                }
            }
        }

        layout_voting_from_services.setOnClickListener {
            guardWalletExist { goTo(ActivityVoting::class.java, true) }
        }

        layout_feed_price.setOnClickListener {
            goTo(ActivityFeedPrice::class.java, true)
        }

        layout_recharge_and_withdraw_of_service.setOnClickListener {
            guardWalletExist { goTo(ActivityDepositAndWithdraw::class.java, true) }
        }

        layout_kline_setting_of_service.setOnClickListener{
            goTo(ActivityKLineIndexSetting::class.java,true,args = jsonObjectfromKVS("result_promise", Promise()))
        }
    }

    /**
     * 获取用户的 full_account_data 数据，并且获取余额里所有 asset 的资产详细信息。
     */
    private fun get_full_account_data_and_asset_hash(account_name_or_id: String): Promise {
        //  TODO:后期移动到 ChainObjectManager里
        return ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_name_or_id).then {
            val full_account_data = it as JSONObject
            val list = JSONArray()
            for (balance in full_account_data.getJSONArray("balances")) {
                list.put(balance!!.getString("asset_type"))
            }
            return@then ChainObjectManager.sharedChainObjectManager().queryAllAssetsInfo(list).then {
                //  (void)asset_hash 省略，缓存到 ChainObjectManager 即可。
                return@then full_account_data
            }
        }
    }
}
