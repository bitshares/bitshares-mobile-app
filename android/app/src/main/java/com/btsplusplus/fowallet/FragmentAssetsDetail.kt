package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentAssetsDetail.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentAssetsDetail.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentAssetsDetail : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _ctx: Context? = null
    private var _view: View? = null
    private var _loadStartID: Int = 0
    private var _full_account_data: JSONObject? = null
    private var _loading: Boolean = true
    private var _dataArray = mutableListOf<JSONObject>()

    override fun onInitParams(args: Any?) {
        if (args != null) {
            _full_account_data = args as JSONObject
            queryAccountHistory()
        }
    }

    private fun queryAccountHistory() {
        _loading = true

        //  查询最新的 100 条记录。
        val stop = "1.${EBitsharesObjectType.ebot_operation_history.value}.0"
        val start = "1.${EBitsharesObjectType.ebot_operation_history.value}.${_loadStartID}"
        //  start - 从指定ID号往前查询（包含该ID号），如果指定ID为0，则从最新的历史记录往前查询。结果包含 start。
        //  stop  - 指定停止查询ID号（结果不包含该ID），如果指定为0，则查询到最早的记录位置（or达到limit停止。）结果不包含该 stop ID。
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        conn.async_exec_history("get_account_history", jsonArrayfrom(_full_account_data!!.getJSONObject("account").getString("id"), stop, 100, start)).then {
            return@then onGetAccountHistoryResponsed(it as JSONArray)
        }.catch {
            _loading = false
            showToast(_ctx!!.resources.getString(R.string.tip_network_error))
        }
    }

    private fun onGetAccountHistoryResponsed(data_array: JSONArray): Promise {
        val block_num_hash = JSONObject()
        val query_ids = JSONObject()
        for (history in data_array) {
            if (history == null) {
                continue
            }
            block_num_hash.put(history.getString("block_num"), true)
            val op = history.getJSONArray("op")
            val op_code = op[0] as Int
            val op_data = op[1] as JSONObject
            OrgUtils.extractObjectID(op_code, op_data, query_ids)
        }

        //  额外查询 各种操作以来的资产信息、帐号信息、时间信息等
        val block_num_list = block_num_hash.keys().toJSONArray()
        val query_ids_list = query_ids.keys().toJSONArray()

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val p1 = chainMgr.queryAllGrapheneObjects(query_ids_list)
        val p2 = chainMgr.queryAllBlockHeaderInfos(block_num_list, false)

        return Promise.all(p1, p2).then {
            onQueryAccountHistoryDetailResponsed(data_array)
            return@then true
        }
    }

    private fun onQueryAccountHistoryDetailResponsed(data_array: JSONArray) {
        _loading = false
        _dataArray.clear()

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        for (history in data_array) {
            if (history == null) {
                continue
            }
            val block_num = history.getString("block_num")
            val block_header = chainMgr.getBlockHeaderInfoByBlockNumber(block_num)
            //  根据操作op构造显示内容
            val op = history.getJSONArray("op")
            val op_data = op[1] as JSONObject
            val op_code = op[0] as Int
            val opresult = history.optJSONArray("result")
            val uidata = OrgUtils.processOpdata2UiData(op_code, op_data, opresult, false, _ctx!!)

            //  添加到列表
            val item = JSONObject().apply {
                put("typename", uidata.getString("name"))
                put("desc", uidata.getString("desc"))
                put("block_time", block_header?.getString("timestamp") ?: "")
                put("history", history)
                put("typecolor", uidata.getInt("color"))
            }
            _dataArray.add(item)
        }

        //  刷新
        refreshUI()
    }

    /**
     * 合并账户历史中的订单成交条目
     */
    private fun mergeFillOrderHistory(data_array: JSONArray): JSONArray {
        //  TODO:未完成，暂不合并。
        return data_array
    }

    private fun refreshUI() {
        if (_loading || _view == null) {
            return
        }
        val act = this.activity
        if (act != null) {
            val container: LinearLayout = _view!!.findViewById(R.id.layout_my_assets_detail_from_my_fragment)
            container.removeAllViews()
            if (_dataArray.size > 0) {
                val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                layout_params.gravity = Gravity.CENTER_VERTICAL
                for (item in _dataArray) {
                    createCell(container, layout_params, _ctx!!, item)
                }
            } else {
                container.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, _ctx!!.resources.getString(R.string.kVcAssetTipNoActivity)))
            }
        }
    }

    private fun createCell(ly: LinearLayout, layout_params: LinearLayout.LayoutParams, ctx: Context, data: JSONObject) {
        val ly_wrap = LinearLayout(ctx)
        ly_wrap.orientation = LinearLayout.VERTICAL

        // layout1
        val ly1 = LinearLayout(ctx)
        ly1.orientation = LinearLayout.HORIZONTAL
        ly1.layoutParams = layout_params
        ly1.setPadding(0, toDp(5.0f), 0, 0)

        val tv1 = TextView(ctx)
        tv1.text = data.getString("typename")
        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        //  设置颜色
        if (data.has("typecolor")) {
            tv1.setTextColor(resources.getColor(data.getInt("typecolor")))
        } else {
            tv1.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
        tv1.gravity = Gravity.CENTER_VERTICAL

        val tv2 = TextView(ctx)
        tv2.text = Utils.fmtAccountHistoryTimeShowString(data.getString("block_time"))
        tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10.0f)
        tv2.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv2.gravity = Gravity.TOP or Gravity.RIGHT
        var layout_tv2 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_tv2.weight = 1.0f
        layout_tv2.gravity = Gravity.RIGHT
        tv2.layoutParams = layout_tv2

        ly1.addView(tv1)
        ly1.addView(tv2)

        // layout2
        val ly2 = LinearLayout(ctx)
        ly2.orientation = LinearLayout.HORIZONTAL
        ly2.layoutParams = layout_params

        val tv5 = TextView(ctx)
        tv5.text = data.getString("desc")
        tv5.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv5.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv5.gravity = Gravity.CENTER_VERTICAL
        tv5.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        tv5.setPadding(0, 0, 0, toDp(6f))

        ly2.addView(tv5)

        // 线
        val lv_line = View(ctx)
        var layout_line = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(1.0f))
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = layout_line

        ly_wrap.addView(ly1)
        ly_wrap.addView(ly2)
        ly_wrap.addView(lv_line)

        ly.addView(ly_wrap)
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_assets_detail, container, false)
        refreshUI()
        return _view
    }

    // TODO: Rename method, update argument and hook method into UI event
    fun onButtonPressed(uri: Uri) {
        listener?.onFragmentInteraction(uri)
    }

    override fun onDetach() {
        super.onDetach()
        listener = null
    }

    /**
     * This interface must be implemented by activities that contain this
     * fragment to allow an interaction in this fragment to be communicated
     * to the activity and potentially other fragments contained in that
     * activity.
     *
     *
     * See the Android Training lesson [Communicating with Other Fragments]
     * (http://developer.android.com/training/basics/fragments/communicating.html)
     * for more information.
     */
    interface OnFragmentInteractionListener {
        // TODO: Update argument type and name
        fun onFragmentInteraction(uri: Uri)
    }
}
