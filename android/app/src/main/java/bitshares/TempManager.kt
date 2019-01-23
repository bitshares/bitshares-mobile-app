package bitshares

import android.support.v7.app.AppCompatActivity
import org.json.JSONArray
import org.json.JSONObject

class TempManager {
    companion object {
        private var _sharedTempManager = TempManager()

        fun sharedTempManager(): TempManager {
            return _sharedTempManager
        }
    }

    private var args: Any? = null                    //  界面跳转的参数信息(直接保存在这里）

    fun set_args(value: Any?) {
        args = value
    }

    fun get_args(): Any? {
        return args
    }

    fun get_args_as_JSONArray(): JSONArray {
        return get_args() as JSONArray
    }

    fun get_args_as_JSONObject(): JSONObject {
        return get_args() as JSONObject
    }

    //  ---- 账号搜索 callback ----
    private var _callback_query_account: ((activity: AppCompatActivity, account_info: JSONObject) -> Unit)? = null

    fun set_query_account_callback(callback: (activity: AppCompatActivity, account_info: JSONObject) -> Unit) {
        _callback_query_account = callback
    }

    fun call_query_account_callback(last_activity: AppCompatActivity, account_info: JSONObject) {
        if (_callback_query_account != null) {
            _callback_query_account!!(last_activity, account_info)
            _callback_query_account = null
        }
    }

    var favoritesMarketDirty: Boolean = false       //  自选市场是否发生变化，需要重新加载。
    var customMarketDirty: Boolean = false          //  自定义交易对发生变化，需要重新加载。
    var tickerDataDirty: Boolean = false            //  交易对 ticker 数据有任意一对发生变化就会设置该标记。
    var userLimitOrderDirty: Boolean = false        //  用户限价单信息发生变化，需要重新加载。（交易界面->全部订单管理->取消订单->返回交易界面。）
}