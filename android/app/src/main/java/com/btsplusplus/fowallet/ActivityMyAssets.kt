package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.ImageButton
import android.widget.TextView
import bitshares.AppCacheManager
import bitshares.btsppLogCustom
import bitshares.jsonArrayfrom
import bitshares.jsonObjectfromKVS
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_my_assets.*
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityMyAssets : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private lateinit var _userAssetDetailInfos: JSONObject
    private lateinit var _full_account_data: JSONObject

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_my_assets)

        //  获取参数
        val args = btspp_args_as_JSONArray()
        _userAssetDetailInfos = args[0] as JSONObject
        _full_account_data = args[1] as JSONObject

        //  设置标题
        val account = _full_account_data.getJSONObject("account")
        val target_name = account.getString("name")
        if (WalletManager.sharedWalletManager().isMyselfAccount(target_name)) {
            findViewById<TextView>(R.id.title).text = resources.getString(R.string.kVcTitleMyBalance)
            //  不显示关注按钮
            btn_fav.visibility = View.GONE
        } else {
            findViewById<TextView>(R.id.title).text = target_name
            //  关注按钮事件
            if (AppCacheManager.sharedAppCacheManager().get_all_fav_accounts().has(target_name)) {
                findViewById<ImageButton>(R.id.btn_fav).setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
            } else {
                findViewById<ImageButton>(R.id.btn_fav).setColorFilter(resources.getColor(R.color.theme01_textColorGray))
            }
            btn_fav.setOnClickListener {
                _onFavClicked(it as ImageButton, account)
            }
        }

        layout_back_from_my_assets.setOnClickListener { finish() }

        setFullScreen()

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_my_assets
        view_pager = view_pager_of_my_assets

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()
    }

    /**
     * 事件 - 关注/取消关注
     */
    private fun _onFavClicked(btn: ImageButton, account: JSONObject) {
        val pAppCache = AppCacheManager.sharedAppCacheManager()
        val account_name = account.getString("name")
        if (pAppCache.get_all_fav_accounts().has(account_name)) {
            pAppCache.remove_fav_account(account_name)
            btn.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
            showToast(resources.getString(R.string.kTipsUnfollowed))
            //  [统计]
            btsppLogCustom("event_account_remove_fav", jsonObjectfromKVS("account", account_name))
        } else {
            pAppCache.set_fav_account(jsonObjectfromKVS("name", account_name, "id", account.getString("id")))
            btn.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
            showToast(resources.getString(R.string.kTipsFollowed))
            //  [统计]
            btsppLogCustom("event_account_add_fav", jsonObjectfromKVS("account", account_name))
        }
        pAppCache.saveFavAccountsToFile()
    }

    private fun setViewPager() {
        view_pager!!.adapter = ViewPagerAdapter(super.getSupportFragmentManager(), fragmens)
        val f: Field = ViewPager::class.java.getDeclaredField("mScroller")
        f.isAccessible = true
        val vpc = ViewPagerScroller(view_pager!!.context, OvershootInterpolator(0.6f))
        f.set(view_pager, vpc)
        vpc.duration = 700

        view_pager!!.setOnPageChangeListener(object : ViewPager.OnPageChangeListener {
            override fun onPageScrollStateChanged(state: Int) {
            }

            override fun onPageScrolled(position: Int, positionOffset: Float, positionOffsetPixels: Int) {
            }

            override fun onPageSelected(position: Int) {
                println(position)
                tablayout!!.getTabAt(position)!!.select()
            }
        })
    }

    private fun setFragments() {
        fragmens.add(FragmentAssets().initialize(jsonArrayfrom(_userAssetDetailInfos, _full_account_data)))
        fragmens.add(FragmentAssetsDetail().initialize(_full_account_data))
        fragmens.add(FragmentAssetsHtlcList().initialize(_full_account_data))
        fragmens.add(FragmentVestingBalance().initialize(_full_account_data))
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                val pos = tab.position
                view_pager!!.setCurrentItem(pos, true)
                fragmens[pos].let {
                    if (it is FragmentAssetsHtlcList) {
                        it.queryUserHTLCs()
                    } else if (it is FragmentVestingBalance) {
                        it.queryVestingBalance()
                    }
                }
            }

            override fun onTabUnselected(tab: TabLayout.Tab) {
                //tab未被选择的时候回调
            }

            override fun onTabReselected(tab: TabLayout.Tab) {
                //tab重新选择的时候回调
            }
        })
    }

}
