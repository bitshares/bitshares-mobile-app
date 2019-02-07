package com.btsplusplus.fowallet

import android.content.Context
import android.os.Bundle
import android.support.v7.app.AppCompatActivity
import bitshares.LangManager

abstract class BtsppActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onStop() {
        super.onStop()
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    override fun attachBaseContext(newBase: Context?) {
        super.attachBaseContext(LangManager.sharedLangManager().getAttachBaseContext(newBase!!, null))
    }
}