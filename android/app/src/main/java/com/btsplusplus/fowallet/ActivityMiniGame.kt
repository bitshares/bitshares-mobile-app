package com.btsplusplus.fowallet

import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.webkit.*
import bitshares.JsCallNativeRouter
import bitshares.Utils
import kotlinx.android.synthetic.main.activity_mini_game.*
import org.json.JSONObject

//  TODO: pending

class ActivityMiniGame : BtsppActivity() {

    lateinit var web_view: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_mini_game)

        web_view = findViewById(R.id.web_view_of_game)

        //  设置webview参数
        web_view.setBackgroundColor(Color.TRANSPARENT)
        web_view.setPadding(0, 0, 0, 0)
        web_view.scrollBarStyle = View.SCROLLBARS_INSIDE_OVERLAY
        web_view.webViewClient = WebViewClient()
        val setting = web_view.settings
        //setting.cacheMode = WebSettings.LOAD_NO_CACHE
        setting.javaScriptEnabled = true
        setting.javaScriptCanOpenWindowsAutomatically = true

        web_view.webViewClient = object : WebViewClient() {

            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {

                // Remark 默认解析为何无法获取协议 (自己写了一个)
                // var uri = Uri.parse(request!!.url.toString())
                var urlstr = request!!.url.toString()
                val uri = Utils.parseUri(urlstr)

                // 指定为 js 协议
                if (uri["protocol"] == "js") {
                    JsCallNativeRouter().initWithWebView(web_view, uri["base_name"].toString(), uri["method_name"].toString(), uri["params"] as JSONObject).call()
                    return true
                }

                return super.shouldOverrideUrlLoading(view, request)
            }
        }

        web_view.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                println(consoleMessage!!.message())
                return super.onConsoleMessage(consoleMessage)
            }
        }

        //  加载
        web_view.loadUrl("file:///android_asset/www/game/index.html")

        layout_back_from_game.setOnClickListener { finish() }

        button_refresh_of_game.setOnClickListener { web_view.reload() }

        setFullScreen()
    }

}
