package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_index_my.*

class ActivityIndexMy : BtsppActivity() {

    /**
     * 重载 - 返回键按下
     */
    override fun onBackPressed() {
        goHome()
    }

    override fun onResume() {
        super.onResume()
        _refreshFaceUI()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_index_my, navigationBarColor = R.color.theme01_tabBarColor)

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  设置底部导航栏样式
        setBottomNavigationStyle(3)

        //  设置图标颜色
        val iconcolor = resources.getColor(R.color.theme01_textColorNormal)
        img_icon_avatar.setColorFilter(iconcolor)
        img_icon_assets.setColorFilter(iconcolor)
        img_icon_orders.setColorFilter(iconcolor)
        img_icon_wallet.setColorFilter(iconcolor)
        img_icon_proposal.setColorFilter(iconcolor)
        img_icon_faq.setColorFilter(iconcolor)
        img_icon_setting.setColorFilter(iconcolor)
        img_icon_about.setColorFilter(iconcolor)

        //  刷新UI
        _refreshFaceUI()

        //  需要判断登录
        layout_my_top.setOnClickListener {
            if (WalletManager.sharedWalletManager().isWalletExist()) {
                goTo(ActivityAccountInfo::class.java, true)
            } else {
                goTo(ActivityLogin::class.java, true)
            }
        }

        layout_setting_from_my.setOnClickListener {
            val saveCurrLangCode = LangManager.sharedLangManager().currLangCode
            val result_promise = Promise()
            goTo(ActivitySetting::class.java, true, args = jsonObjectfromKVS("result_promise", result_promise))
            result_promise.then {
                if (LangManager.sharedLangManager().currLangCode != saveCurrLangCode){
                    recreate()
                }
            }
        }

        //  [待处提案] 需要判断登录
        layout_my_proposal_waiting_for_process.setOnClickListener {
            guardWalletExist {
                goTo(ActivityProposal::class.java, true)
            }
        }

        //  [钱包 & 多签]
        layout_my_wallet_and_muti_signature.setOnClickListener {
            guardWalletExist {
                if (WalletManager.sharedWalletManager().isPasswordMode()) {
                    alerShowMessageConfirm(resources.getString(R.string.registerLoginPageWarmTip), R.string.kLblTipsPasswordModeNotSupportMultiSign.xmlstring(this)).then {
                        if (it != null && it as Boolean) {
                            val result_promise = Promise()
                            goTo(ActivityUpgradeToWalletMode::class.java, true, args = jsonObjectfromKVS("result_promise", result_promise))
                            result_promise.then {
                                if (it != null && it as Boolean) {
                                    goTo(ActivityWalletManager::class.java, true)
                                }
                            }
                        }
                        return@then null
                    }
                } else {
                    goTo(ActivityWalletManager::class.java, true)
                }
            }
        }

        //  我的资产：需要钱包存在
        layout_my_assets_of_my.setOnClickListener {
            guardWalletExist {
                viewUserAssets(WalletManager.sharedWalletManager().getWalletAccountName()!!)
            }
        }

        //  订单管理：需要钱包存在
        layout_order_management_of_my.setOnClickListener {
            guardWalletExist {
                val uid = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account").getString("id")
                viewUserLimitOrders(uid, null)
            }
        }

        layout_faq_from_my.setOnClickListener {
            goToWebView(resources.getString(R.string.myPageQA), "http://btspp.io/qa.html")
        }

        layout_about_from_my.setOnClickListener {
            goTo(ActivityAbout::class.java, true)
        }
    }

    private fun _refreshFaceUI() {
        val walletMgr = WalletManager.sharedWalletManager()
        if (walletMgr.isWalletExist()) {
            val account = walletMgr.getWalletAccountInfo()!!.getJSONObject("account")
            //  第一行
            val name = account.getString("name")
            if (walletMgr.isLocked()) {
                findViewById<TextView>(R.id.label_txt_accoutname).text = "${name}(${R.string.myPageLabelAccountLocked.xmlstring(this)})"
            } else {
                findViewById<TextView>(R.id.label_txt_accoutname).text = "${name}(${R.string.myPageLabelAccountUnlocked.xmlstring(this)})"
            }
            //  第二行
            if (Utils.isBitsharesVIP(account.optString("membership_expiration_date", ""))) {
                findViewById<TextView>(R.id.label_txt_status).text = "${R.string.myPageLabelMembership.xmlstring(this)}${R.string.myPageLabelMembershipLifetime.xmlstring(this)}"
            } else {
                findViewById<TextView>(R.id.label_txt_status).text = "${R.string.myPageLabelMembership.xmlstring(this)}${R.string.myPageLabelMembershipBasic.xmlstring(this)}"
            }
        } else {
            findViewById<TextView>(R.id.label_txt_accoutname).text = R.string.nameAccountManager.xmlstring(this)
            findViewById<TextView>(R.id.label_txt_status).text = R.string.myPageClickToLogin.xmlstring(this)
        }
    }
}
