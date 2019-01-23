package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.v7.app.AppCompatActivity

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

}