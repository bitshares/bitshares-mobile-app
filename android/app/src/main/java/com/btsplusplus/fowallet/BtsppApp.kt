package com.btsplusplus.fowallet

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import bitshares.LangManager
import java.util.*
import kotlin.reflect.KClass

class BtsppApp : Application() {

    companion object {

        private var _app_instance: BtsppApp? = null

        fun getInstance(): BtsppApp {
            return _app_instance!!
        }
    }

    private val _activity_list = Collections.synchronizedList(LinkedList<Activity>())

    /**
     *  (public) 导航 - 关闭所有 Activity，直到目标 Activity 出现。如果目标 Activity 为空，则关闭到 navigation 的顶层界面。
     *  REMARK - 必须确保堆栈用存在对应的 Activity，否则会全部 finish 掉。
     */
    fun finishActivityTo(target_activity_class: KClass<*>? = null) {
        while (_activity_list.size > 0) {
            val last = _activity_list.last()
            val last_class = last::class
            if (target_activity_class == null) {
                if (last_class == ActivityIndexMarkets::class ||
                        last_class == ActivityIndexCollateral::class ||
                        last_class == ActivityIndexServices::class ||
                        last_class == ActivityIndexMy::class) {
                    //  已经达到最外层界面：终止
                    break
                }
            } else if (target_activity_class == last_class) {
                //  已经达到目标界面：终止
                break
            }
            //  关闭该界面
            last.finish()
            _activity_list.remove(last)
        }
    }

    fun finishActivityToNavigationTop() {
        finishActivityTo(null)
    }

    /**
     *  (public) 导航 - 关闭所有 Activity。
     */
    fun finishAllActivity() {
        while (_activity_list.size > 0) {
            _activity_list.removeAt(_activity_list.size - 1).finish()
        }
    }

    /**
     *  (public) 导航 - 获取顶部 Activity。
     */
    fun getTopActivity(): Activity? {
        return _activity_list.lastOrNull()
    }

    override fun onCreate() {
        super.onCreate()
        _app_instance = this
        registerActivityListener()
    }

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(LangManager.sharedLangManager().onAttach(base!!))
    }

    /**
     *  (privat) 注册 Activity 生命周期监听事件
     */
    private fun registerActivityListener() {
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity?, savedInstanceState: Bundle?) {
                _activity_list.add(activity)
            }

            override fun onActivityStarted(activity: Activity?) {
                //  ...
            }

            override fun onActivityResumed(activity: Activity?) {
                //  ...
            }

            override fun onActivityPaused(activity: Activity?) {
                //  ...
            }

            override fun onActivityStopped(activity: Activity?) {
                //  ...
            }

            override fun onActivityDestroyed(activity: Activity?) {
                _activity_list.remove(activity)
            }

            override fun onActivitySaveInstanceState(activity: Activity?, outState: Bundle?) {
                //  ...
            }
        })
    }

}