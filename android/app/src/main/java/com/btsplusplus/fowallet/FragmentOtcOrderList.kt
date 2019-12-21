package com.btsplusplus.fowallet


import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import bitshares.OtcManager
import bitshares.Promise
import bitshares.forEach
import bitshares.xmlstring
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
    private lateinit var _auth_info: JSONObject
    private var _user_type = OtcManager.EOtcUserType.eout_normal_user
    private var _order_status = OtcManager.EOtcOrderStatus.eoos_all

    override fun onInitParams(args: Any?) {
        val json = args as JSONObject
        _auth_info = json.getJSONObject("auth_info")
        _user_type = json.get("user_type") as OtcManager.EOtcUserType
        _order_status = json.get("order_status") as OtcManager.EOtcOrderStatus
    }

    private fun onQueryCurrentPageOrdersResponsed(ctx: Context, responsed: JSONObject?) {
        val records = responsed?.optJSONObject("data")?.optJSONArray("records")
        refreshUI(ctx, records)
    }

    fun queryCurrentPageOrders() {
        waitingOnCreateView().then {
            val ctx = it as Context
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
            mask.show()
            val otc = OtcManager.sharedOtcManager()
            val p1 = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                otc.queryUserOrders(otc.getCurrentBtsAccount(), OtcManager.EOtcOrderType.eoot_query_all, _order_status, 0, 50)
            } else {
                otc.queryMerchantOrders(otc.getCurrentBtsAccount(), OtcManager.EOtcOrderType.eoot_query_all, _order_status, 0, 50)
            }
            p1.then {
                mask.dismiss()
                onQueryCurrentPageOrdersResponsed(ctx, it as? JSONObject)
                return@then null
            }.catch { err ->
                mask.dismiss()
                otc.showOtcError(ctx as Activity, err)
            }
            return@then null
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        super.onCreateView(inflater, container, savedInstanceState)
        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_otc_order_list, container, false)
        return _view
    }

    private fun refreshUI(ctx: Context, data_array: JSONArray?) {
        if (_view == null) {
            return
        }
        val layout = _view!!.findViewById<LinearLayout>(R.id.layout_order_lists_from_fragment_orc_merchant)
        layout.removeAllViews()
        if (data_array == null || data_array.length() == 0) {
            //  空列表
            if (_user_type == OtcManager.EOtcUserType.eout_merchant && _order_status == OtcManager.EOtcOrderStatus.eoos_mc_wait_process) {
                layout.addView(ViewUtils.createEmptyCenterLabel(ctx, R.string.kOtcOrderEmptyLabelWaitProcessing.xmlstring(ctx)))
            } else {
                layout.addView(ViewUtils.createEmptyCenterLabel(ctx, R.string.kOtcOrderEmptyLabel.xmlstring(ctx)))
            }
        } else {
            data_array.forEach<JSONObject> {
                val order = it!!
                val view = ViewOtcMerchantOrderCell(ctx, order, _user_type)
                view.setOnClickListener { onOrderClicked(ctx, order) }
                layout.addView(view)
            }
        }
    }

    private fun onOrderClicked(ctx: Context, order: JSONObject) {
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
        mask.show()
        val p1 = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
            otc.queryUserOrderDetails(otc.getCurrentBtsAccount(), order.getString("orderId"))
        } else {
            otc.queryMerchantOrderDetails(otc.getCurrentBtsAccount(), order.getString("orderId"))
        }
        p1.then {
            mask.dismiss()
            val responsed = it as JSONObject
            //  转到订单详情界面
            val result_promise = Promise()
            (ctx as Activity).goTo(ActivityOtcOrderDetails::class.java, true, args = JSONObject().apply {
                put("auth_info", _auth_info)
                put("user_type", _user_type)
                put("order_details", responsed.getJSONObject("data"))
                put("result_promise", result_promise)
            })
            result_promise.then {
                if (it != null && it as Boolean) {
                    _onOrderDetailCallback()
                }
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(ctx as Activity, err)
        }
    }

    private fun _onOrderDetailCallback() {
        //  订单状态变更：刷新界面
        queryCurrentPageOrders()
    }

}
