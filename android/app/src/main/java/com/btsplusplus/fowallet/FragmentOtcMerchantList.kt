package com.btsplusplus.fowallet


import android.content.Context
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import bitshares.dp
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
class FragmentOtcMerchantList : BtsppFragment() {

    private var _ctx: Context? = null
    private var _view: View? = null
    private lateinit var _data: JSONArray
    private var _asset_name: String = ""
    private var _entry: String = ""

    override fun onInitParams(args: Any?) {
        val _args = args as JSONObject
        _asset_name = _args.getString("asset_name")
        _entry = args.getString("entry")
        _data = _args.getJSONArray("data")
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_otc_merchant_list, container, false)
        refreshUI()
        return _view
    }

    private fun refreshUI() {
        if (_view == null) {
            return
        }
        val layout: LinearLayout = _view!!.findViewById(R.id.layout_buy_from_fragment_merchant_list)
        if (_data.length() == 0){
            layout.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, "没有任何商家在线"))
        } else {
            _data.forEach<JSONObject> {
                val view = ViewOtcMerchantCell(_ctx!!,_entry,_asset_name,it!!)
                layout.addView(view)
            }
        }
    }
}
