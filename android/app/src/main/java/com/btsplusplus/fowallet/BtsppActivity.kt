package com.btsplusplus.fowallet

import android.content.Context
import android.os.Bundle
import android.support.v7.app.AppCompatActivity
import bitshares.*
import org.json.JSONArray
import org.json.JSONObject

private const val ARG_PARAM_ID = "btspp_activity_param_id"

abstract class BtsppActivity : AppCompatActivity() {

    private var _btspp_param_id = 0
    protected var _btspp_params: Any? = null

    fun btspp_args_as_JSONArray(): JSONArray {
        return _btspp_params as JSONArray
    }

    fun btspp_args_as_JSONObject(): JSONObject {
        return _btspp_params as JSONObject
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState != null) {
            _btspp_param_id = savedInstanceState.getInt(ARG_PARAM_ID)
            //  [统计]
            btsppLogCustom("onBtsppParamsRestore", jsonObjectfromKVS("activity", this::class.java.name, "param_id", _btspp_param_id))
        } else {
            _btspp_param_id = intent.getIntExtra(BTSPP_START_ACTIVITY_PARAM_ID, -1)
        }
        if (_btspp_param_id > 0) {
            _btspp_params = ParametersManager.sharedParametersManager().getParams(_btspp_param_id)
        }
    }

    override fun onStop() {
        super.onStop()
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    override fun finish() {
        if (_btspp_param_id > 0) {
            btsppLogCustom("onFinishDeleteParams", jsonObjectfromKVS("activity", this::class.java.name, "param_id", _btspp_param_id))
            ParametersManager.sharedParametersManager().delParams(_btspp_param_id)
        }
        super.finish()
    }

    /**
     * 系统返回键
     */
    override fun onBackPressed() {
        onBackClicked(null)
    }

    open fun onBackClicked(result: Any?) {
        finish()
    }

    override fun attachBaseContext(newBase: Context?) {
        super.attachBaseContext(LangManager.sharedLangManager().onAttach(newBase!!))
    }

    override fun onSaveInstanceState(outState: Bundle?) {
        //  保存参数
        outState?.putInt(ARG_PARAM_ID, _btspp_param_id)
        super.onSaveInstanceState(outState)
        //  [统计]
        btsppLogCustom("onBtsppParamsSave", jsonObjectfromKVS("activity", this::class.java.name))
    }
}