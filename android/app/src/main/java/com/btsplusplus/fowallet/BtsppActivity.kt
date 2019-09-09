package com.btsplusplus.fowallet

import android.annotation.TargetApi
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.support.v7.app.AppCompatActivity
import bitshares.*
import org.json.JSONArray
import org.json.JSONObject

private const val ARG_PARAM_ID = "btspp_activity_param_id"
private const val ARG_RC_REQUEST_PERMISSION = 100

enum class EBtsppPermissionResult(val value: Int) {
    GRANTED(0x0),                   //  有权限
    SHOW_RATIONALE(0x1),            //  显示原因（没勾选不再提示）
    DONT_ASK_AGAIN(0x2),            //  不在提示（前往系统界面设置）
}

abstract class BtsppActivity : AppCompatActivity() {

    private var _btspp_param_id = 0
    protected var _btspp_params: Any? = null
    private var _btspp_permission_promise: Promise? = null

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

    /**
     * 权限处理
     */
    @TargetApi(Build.VERSION_CODES.M)
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != ARG_RC_REQUEST_PERMISSION) {
            return
        }

        assert(_btspp_permission_promise != null)
        var idx = 0
        for (result in grantResults) {
            val permission = permissions[idx]
            if (PackageManager.PERMISSION_GRANTED != result) {
                if (this.shouldShowRequestPermissionRationale(permission)) {
                    _btspp_permission_promise!!.resolve(EBtsppPermissionResult.SHOW_RATIONALE.value)
                } else {
                    _btspp_permission_promise!!.resolve(EBtsppPermissionResult.DONT_ASK_AGAIN.value)
                }
                break
            }
            ++idx
        }

        _btspp_permission_promise!!.resolve(EBtsppPermissionResult.GRANTED.value)
    }

    fun guardPermissions(permission: String): Promise {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            _btspp_permission_promise = Promise()
            requestPermissions(arrayOf(permission), ARG_RC_REQUEST_PERMISSION)
            return _btspp_permission_promise!!
        } else {
            return Promise._resolve(EBtsppPermissionResult.GRANTED.value)
        }
    }
}