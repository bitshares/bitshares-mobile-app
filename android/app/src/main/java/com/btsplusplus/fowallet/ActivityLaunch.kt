package com.btsplusplus.fowallet

import android.content.Intent
import android.graphics.Color.TRANSPARENT
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.View
import bitshares.*
import bitshares.serializer.T_Base
import com.crashlytics.android.Crashlytics
import com.crashlytics.android.answers.Answers
import com.flurry.android.FlurryAgent
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import io.fabric.sdk.android.Fabric
import org.json.JSONArray
import org.json.JSONObject
import java.util.*

class ActivityLaunch : BtsppActivity() {

    private var _appNativeVersion: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  初始化 Fabric
        Fabric.with(this, Crashlytics(), Answers())

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
            Crashlytics.setUserName(accountName)
            FlurryAgent.setUserId(accountName)
        }

        //  初始化配置
        _appNativeVersion = Utils.appVersionName(this)
        initCustomConfig()

        //  启动日志
        btsppLogCustom("event_app_start", jsonObjectfromKVS("ver", _appNativeVersion))

        //  初始化完毕后启动。
        startInit(true)
    }

    /**
     * start init graphene network & app
     */
    private fun startInit(first_init: Boolean) {
        val waitPromise = asyncWait()
        checkUpdate().then {
            val pVersionConfig = it as? JSONObject
            SettingManager.sharedSettingManager().serverConfig = pVersionConfig
            return@then Promise.all(waitPromise, asyncInitBitshares()).then {
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
        if (pConfig != null) {
            val pNewestVersion = pConfig.optString("version", "")
            if (pNewestVersion != "") {
                val ret = Utils.compareVersion(pNewestVersion, _appNativeVersion)
                if (ret > 0) {
                    //  有更新
                    var message = pConfig.optString(resources.getString(R.string.launchTipVersionKey), "")
                    if (message == "") {
                        message = String.format(resources.getString(R.string.launchTipDefaultNewVersion), pNewestVersion)
                    }
                    _showAppUpdateWindow(message, pConfig.getString("appURL"), pConfig.getString("force").toInt() != 0)
                    return
                }
            }
        }
        //  没更新则直接启动
        _enterToMain()
    }

    /**
     *  提示app更新
     */
    private fun _showAppUpdateWindow(message: String, url: String, forceUpdate: Boolean) {
        var btn_cancel: String? = null
        if (!forceUpdate) {
            btn_cancel = resources.getString(R.string.kRemindMeLatter)
        }
        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), message, btn_ok = resources.getString(R.string.kUpgradeNow), btn_cancel = btn_cancel).then {
            //  进入APP
            _enterToMain()
            //  立即升级：打开下载。
            if (it != null && it as Boolean) {
                openURL(url)
            }
        }
    }

    /**
     * 进入主界面
     */
    private fun _enterToMain() {
        val intent = Intent()
        intent.setClass(this, ActivityIndexMarkets::class.java)
        startActivity(intent)
    }

    /**
     * 检测更新
     */
    private fun checkUpdate(): Promise {
        val p = Promise()
        Utils.now_ts()
        val version_url = "https://btspp.io/app/android/o_${_appNativeVersion}/version.json?t=${Date().time}"
        OrgUtils.asyncJsonGet(version_url).then {
            p.resolve(it as? JSONObject)
            return@then null
        }.catch {
            p.resolve(null)
        }
        return p
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
    private fun asyncInitBitshares(): Promise {
        val p = Promise()

        val connMgr = GrapheneConnectionManager.sharedGrapheneConnectionManager()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        //  初始化链接
        connMgr.Start(resources.getString(R.string.serverWssLangKey)).then { success ->
            //  初始化网络相关数据
            chainMgr.grapheneNetworkInit().then { data ->
                //  初始化逻辑相关数据
                val initTickerData = chainMgr.marketsInitAllTickerData()
                val initGlobalProperties = connMgr.last_connection().async_exec_db("get_global_properties")
                val initFeeAssetInfo = chainMgr.queryFeeAssetListDynamicInfo()  //  查询手续费兑换比例、手续费池等信息
                return@then Promise.all(initTickerData, initGlobalProperties, initFeeAssetInfo).then { data_array ->
                    //  更新全局属性
                    val data_array = data_array as JSONArray
                    chainMgr.updateObjectGlobalProperties(data_array.getJSONObject(1))
                    //  初始化完成之后：启动计划调度任务
                    ScheduleManager.sharedScheduleManager().startTimer()
                    ScheduleManager.sharedScheduleManager().autoRefreshTickerScheduleByMergedMarketInfos()
                    //  初始化完成
                    p.resolve(true)
                    return@then null
                }
            }.catch { error ->
                p.reject(resources.getString(R.string.tip_network_error))
            }
            return@then null
        }.catch { error ->
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
        ChainObjectManager.sharedChainObjectManager().initAll(this)
    }
}
