package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_setting_currency.*
import org.json.JSONObject

class ActivitySettingLanguage : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_setting_currency)

        setFullScreen()

        //  TODO:1.7

        layout_back_from_setting_currency.setOnClickListener { finish() }
    }
}
