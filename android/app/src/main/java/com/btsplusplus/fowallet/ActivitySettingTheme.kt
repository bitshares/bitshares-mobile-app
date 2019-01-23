package com.btsplusplus.fowallet

import android.os.Bundle
import kotlinx.android.synthetic.main.activity_setting_theme.*

//  TODO: pending

class ActivitySettingTheme : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_setting_theme)

        setFullScreen()

        layout_back_from_setting_theme.setOnClickListener { finish() }
    }
}
