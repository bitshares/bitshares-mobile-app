package bitshares

import android.webkit.WebView
import org.json.JSONObject
import java.lang.reflect.Method

class JsCallNativeRouter {

    lateinit var web_view: WebView
    lateinit var base_name: String
    lateinit var action_name: String
    lateinit var params: JSONObject

    fun initWithWebView(web_view: WebView, base_name: String, action_name: String, params: JSONObject): JsCallNativeRouter {
        this.web_view = web_view
        this.base_name = base_name
        this.action_name = action_name
        this.params = params
        return this
    }

    fun call() {
        // Todo test

        val methods = this::class.java.methods.map { it.name }
        if (methods.indexOf(action_name) != -1) {
            val m: Method = this::class.java.getMethod(action_name)
            m.invoke(this)
        }

    }

    // 夺宝提交
    fun gameDuobaoSubmit() {
        val amount = this.params.optDouble("amount", 0.0)

        val params = JSONObject()
        params.put("type", "submit_response")
        params.put("amount", amount)
        this.callJs(params)
    }

    fun btsMethods2() {

    }

    private fun callJs(params: JSONObject) {
        web_view.loadUrl("javascript:onReceiveFromAndroid(" + params.toString() + ")")
    }

}