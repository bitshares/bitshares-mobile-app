package com.btsplusplus.fowallet


import android.content.Context
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import bitshares.OtcOrderStatus
import bitshares.forEach
import org.json.JSONArray
import org.json.JSONObject

// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 *
 */
class FragmentOtcOrderList : BtsppFragment() {

    private var _ctx: Context? = null
    private var _view: View? = null
    private lateinit var _data: JSONArray

    private lateinit var _layout_order_lists: LinearLayout


    override fun onInitParams(args: Any?) {
        _data = args as JSONArray
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_otc_order_list, container, false)
        _layout_order_lists = _view!!.findViewById(R.id.layout_order_lists_from_fragment_orc_merchant)
        refreshUI()
        return _view
    }

    private fun refreshUI(){
        if (_view == null) {
            return
        }

        _layout_order_lists.removeAllViews()
        if (_data.length() == 0){
            _layout_order_lists.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, "没有订单"))
        } else {
            _data.forEach<JSONObject> {
                val view = ViewOtcMerchantOrderCell(_ctx!!, it!!)
                _layout_order_lists.addView(view)
            }
        }
    }

}
