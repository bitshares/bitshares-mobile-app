package com.btsplusplus.fowallet

import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.webkit.WebSettings.LOAD_NO_CACHE
import android.webkit.WebViewClient
import kotlinx.android.synthetic.main.activity_webview.*

class ActivityWebView : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val params = _btspp_params as Array<String>
        assert(params.size == 2)

        setAutoLayoutContentView(R.layout.activity_webview)

        //  设置标题
        title_of_webview.text = params[0]

        //  设置webview参数
        web_view.setBackgroundColor(Color.TRANSPARENT)
        web_view.setPadding(0, 0, 0, 0)
        web_view.scrollBarStyle = View.SCROLLBARS_INSIDE_OVERLAY
        web_view.webViewClient = WebViewClient()
        val setting = web_view.settings
        setting.cacheMode = LOAD_NO_CACHE
        setting.javaScriptEnabled = true
        setting.domStorageEnabled = true

        //  加载
        web_view.loadUrl(params[1])

        layout_back_from_faq.setOnClickListener { finish() }

        button_refresh_of_webview.setOnClickListener { web_view.reload() }

        setFullScreen()
    }

}
