package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.v4.app.Fragment
import bitshares.ParametersManager

private const val ARG_PARAM_ID = "btspp_fragment_param_id"

abstract class BtsppFragment : Fragment() {

    private var _param_id = 0

    /**
     * Fragment通过调用该方法传递参数。
     */
    fun initialize(args: Any?): Fragment {
        val param_id = ParametersManager.sharedParametersManager().genParams(args)
        this.arguments = Bundle().apply {
            putInt(ARG_PARAM_ID, param_id)
        }
        return this
    }

    /**
     * 如果有参数必须重载该方法获取参数。
     */
    open fun onInitParams(args: Any?) {
        //  ...
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            _param_id = it.getInt(ARG_PARAM_ID)
            onInitParams(ParametersManager.sharedParametersManager().getParams(_param_id))
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (_param_id != 0) {
            ParametersManager.sharedParametersManager().delParams(_param_id)
            _param_id = 0
        }
    }
}