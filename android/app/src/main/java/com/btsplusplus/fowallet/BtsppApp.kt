package com.btsplusplus.fowallet

import android.app.Application
import android.content.Context
import bitshares.LangManager

class BtsppApp : Application() {

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(LangManager.sharedLangManager().onAttach(base!!))
    }

}