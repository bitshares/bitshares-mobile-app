package com.btsplusplus.fowallet

import android.app.Application
import android.content.Context
import android.content.res.Configuration
import bitshares.LangManager

class BtsppApp : Application() {

    companion object {

        private var _spInstanceBtsppApp: BtsppApp? = null

        fun sharedBtsppApp():BtsppApp{
            return _spInstanceBtsppApp!!
        }

        fun sharedContext():Context{
            return sharedBtsppApp()
        }
    }

    override fun onCreate() {
        super.onCreate()
        _spInstanceBtsppApp = this
        onLanguageChange()
    }

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(LangManager.sharedLangManager().getAttachBaseContext(base!!, null))
    }

    override fun onConfigurationChanged(newConfig: Configuration?) {
        super.onConfigurationChanged(newConfig)
        onLanguageChange()
    }

    private fun onLanguageChange(){
        LangManager.sharedLangManager().changeLocalLanguage(this, null)
    }
}