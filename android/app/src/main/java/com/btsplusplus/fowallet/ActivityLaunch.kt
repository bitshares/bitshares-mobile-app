package com.btsplusplus.fowallet

import android.content.Intent
import android.graphics.Color.TRANSPARENT
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.View
import bitshares.*
import bitshares.serializer.T_Base
import com.btsplusplus.fowallet.utils.VcUtils
import com.flurry.android.FlurryAgent
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONObject
import java.util.*

class ActivityLaunch : BtsppActivity() {

    companion object {
        /**
         *  (public) 检测APP更新数据。
         */
        fun checkAppUpdate(): Promise {
            if (BuildConfig.kAppCheckUpdate) {
                val p = Promise()
                val version_url = "https://btspp.io/app/android/${BuildConfig.kAppChannelID}_${Utils.appVersionName()}/version.json?t=${Date().time}"
                OrgUtils.asyncJsonGet(version_url).then {
                    p.resolve(it as? JSONObject)
                    return@then null
                }.catch {
                    p.resolve(null)
                }
                return p
            } else {
                return Promise._resolve(null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  初始化Flurry
        FlurryAgent.Builder().withLogEnabled(true).build(this, "H45RRHMWCPMKZNNKR5SR")

        //  初始化启动界面
        setFullScreen()

        //  初始化石墨烯对象序列化类
        T_Base.registerAllType()

        //  初始化参数
        val dm = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(dm)
        Utils.screen_width = dm.widthPixels.toFloat()
        Utils.screen_height = dm.heightPixels.toFloat()
        OrgUtils.initDir(this.applicationContext)
        AppCacheManager.sharedAppCacheManager().initload()

        //  统计设备信息
        val accountName = WalletManager.sharedWalletManager().getWalletAccountName()
        if (accountName != null && accountName != "") {
            FlurryAgent.setUserId(accountName)
        }

        //  初始化配置
        initCustomConfig()

        //  启动日志
        btsppLogCustom("event_app_start", jsonObjectfromKVS("ver", Utils.appVersionName()))

        //  初始化完毕后启动。
        startInit(true)
    }

    /**
     * start init graphene network & app
     */
    private fun startInit(first_init: Boolean) {
        val waitPromise = asyncWait()
        ActivityLaunch.checkAppUpdate().then {
            val pVersionConfig = it as? JSONObject
            SettingManager.sharedSettingManager().serverConfig = pVersionConfig
            return@then Promise.all(waitPromise, asyncInitBitshares(first_init)).then {
                _onLoadVersionJsonFinish(pVersionConfig)
                return@then null
            }
        }.catch {
            if (first_init) {
                showToast(resources.getString(R.string.tip_network_error))
            }
            //  auto restart
            OrgUtils.asyncWait(1000).then {
                startInit(false)
            }
        }
    }

    /**
     * Version加载完毕
     */
    private fun _onLoadVersionJsonFinish(pConfig: JSONObject?) {
        val bFoundNewVersion = VcUtils.processCheckAppVersionResponsed(this, pConfig) {
            //  有新版本，但稍后提醒。则直接启动。
            _enterToMain()
        }
        if (!bFoundNewVersion) {
            //  无新版本，直接启动。
            _enterToMain()
        }
    }

    /**
     * 进入主界面
     */
    private fun _enterToMain() {
        var homeClass: Class<*> = ActivityIndexMarkets::class.java
        if (!BuildConfig.kAppModuleEnableTabMarket) {
            homeClass = ActivityIndexCollateral::class.java
        }
        if (!BuildConfig.kAppModuleEnableTabDebt) {
            homeClass = ActivityIndexServices::class.java
        }
        val intent = Intent()
        intent.setClass(this, homeClass)
        startActivity(intent)
    }

    /**
     * 强制等待
     */
    private fun asyncWait(): Promise {
        return OrgUtils.asyncWait(2000)
    }

    /**
     * 初始化BTS网络，APP启动时候执行一次。
     */
    private fun asyncInitBitshares(first_init: Boolean): Promise {
        val p = Promise()

        val connMgr = GrapheneConnectionManager.sharedGrapheneConnectionManager()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val pAppCache = AppCacheManager.sharedAppCacheManager()

        //  初始化链接
        connMgr.Start(resources.getString(R.string.serverWssLangKey), force_use_random_node = !first_init).then { success ->
            //  初始化网络相关数据
            chainMgr.grapheneNetworkInit().then { data ->
                //  初始化依赖资产（内置资产 + 自定义交易对等）
                val dependence_syms = chainMgr.getConfigDependenceAssetSymbols()
                val custom_asset_ids = pAppCache.get_fav_markets_asset_ids()
                return@then chainMgr.queryAssetsBySymbols(symbols = dependence_syms, asset_ids = custom_asset_ids).then {
                    if (BuildConfig.DEBUG) {
                        //  确保查询成功
                        for (sym in dependence_syms.forin<String>()) {
                            chainMgr.getAssetBySymbol(sym!!)
                        }
                        for (oid in custom_asset_ids.forin<String>()) {
                            chainMgr.getChainObjectByID(oid!!)
                        }
                    }
                    //  生成市场数据结构
                    chainMgr.buildAllMarketsInfos()
                    //  初始化逻辑相关数据
                    val walletMgr = WalletManager.sharedWalletManager()
                    val promise_map = JSONObject().apply {
                        put("kInitTickerData", chainMgr.marketsInitAllTickerData())
                        put("kInitGlobalProperties", connMgr.last_connection().async_exec_db("get_global_properties"))
                        put("kInitFeeAssetInfo", chainMgr.queryFeeAssetListDynamicInfo())     //  查询手续费兑换比例、手续费池等信息
                        //  每次启动都刷新当前账号信息
                        if (walletMgr.isWalletExist()) {
                            put("kInitFullUserData", chainMgr.queryFullAccountInfo(walletMgr.getWalletInfo().getString("kAccountName")))
                        }
                        //  初始化OTC数据
                        put("kQueryConfig", OtcManager.sharedOtcManager().queryConfig())
                    }
                    return@then Promise.map(promise_map).then {
                        //  更新全局属性
                        val data_hash = it as JSONObject
                        chainMgr.updateObjectGlobalProperties(data_hash.getJSONObject("kInitGlobalProperties"))
                        //  更新帐号完整数据
                        val full_account_data = data_hash.optJSONObject("kInitFullUserData")
                        if (full_account_data != null) {
                            AppCacheManager.sharedAppCacheManager().updateWalletAccountInfo(full_account_data)
                        }
                        //  初始化完成之后：启动计划调度任务
                        ScheduleManager.sharedScheduleManager().startTimer()
                        ScheduleManager.sharedScheduleManager().autoRefreshTickerScheduleByMergedMarketInfos()
                        //  初始化完成
                        p.resolve(true)
                        return@then null
                    }
                }
            }.catch {
                p.reject(resources.getString(R.string.tip_network_error))
            }
            return@then null
        }.catch {
            p.reject(resources.getString(R.string.tip_network_error))
        }
        return p
    }

    fun setFullScreen() {
        val dector_view: View = window.decorView
        val option: Int = View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        dector_view.systemUiVisibility = option
        window.navigationBarColor = TRANSPARENT
    }

    /**
     * 初始化自定义启动设置 : (启动仅执行一次)
     */
    private fun initCustomConfig() {
        // 初始化缓存
        ChainObjectManager.sharedChainObjectManager().initConfig(this)
    }
}
