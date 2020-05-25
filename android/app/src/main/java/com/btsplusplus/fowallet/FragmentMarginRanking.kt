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
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.btsplusplus.fowallet.utils.ModelUtils
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentMarginRanking.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentMarginRanking.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentMarginRanking : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _currentView: View? = null
    private var _tradingPair: TradingPair? = null
    private var _feedPriceInfo: BigDecimal? = null
    private var _nTotalSettlementAmount = BigDecimal.ZERO
    private var _mcr: BigDecimal? = null

    private var _ctx: Context? = null

    private var _waiting_draw_infos: JSONArray? = null
    private lateinit var _curr_asset: JSONObject

    override fun onInitParams(args: Any?) {
        val json = args as JSONObject
        _curr_asset = json.getJSONObject("curr_asset")
    }

    fun setCurrentAsset(newAsset: JSONObject) {
        _curr_asset = newAsset
    }

    override fun onControllerPageChanged() {
        waitingOnCreateView().then {
            queryCallOrderData(it as Context)
        }
    }

    private fun queryCallOrderData(ctx: Context) {
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), ctx)
        mask.show()
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        //  1、债仓
        val p1 = conn.async_exec_db("get_call_orders", jsonArrayfrom(_curr_asset.getString("id"), 100))

        //  2、智能币信息（REMARK：不查询缓存）
        val bitasset_data_id = _curr_asset.getString("bitasset_data_id")
        val p2 = chainMgr.queryAllGrapheneObjectsSkipCache(jsonArrayfrom(bitasset_data_id)).then {
            return@then (it as JSONObject).getJSONObject(bitasset_data_id)
        }

        //  3、清算单
        val p3 = chainMgr.querySettlementOrders(_curr_asset.getString("id"), 100)

        Promise.all(p1, p2, p3).then { it ->
            val data_array = it as JSONArray
            //  相关依赖账号
            val idHash = JSONObject()
            for (order in data_array.getJSONArray(0)) {
                idHash.put(order!!.getString("borrower"), true)
            }
            //  背书资产依赖
            val short_backing_asset = data_array.getJSONObject(1).getJSONObject("options").getString("short_backing_asset")
            idHash.put(short_backing_asset, true)
            //  查询依赖
            return@then chainMgr.queryAllGrapheneObjects(idHash.keys().toJSONArray()).then {
                onQueryCallOrderDataResponsed(data_array)
                mask.dismiss()
                return@then null
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    /**
     * 刷新排行榜界面
     */
    private fun onQueryCallOrderDataResponsed(data_array: JSONArray) {
        //  REMARK：数据返回的时候界面尚未创建完毕先保存
        if (_currentView == null) {
            _waiting_draw_infos = data_array
            return
        }

        //  data[0] - 抵押排行信息
        //  data[1] - 喂价信息
        //  保存喂价信息、并计算喂价

        //  1、计算喂价
        val bitasset_data = data_array.getJSONObject(1)
        val short_backing_asset_id = bitasset_data.getJSONObject("options").getString("short_backing_asset")
        _tradingPair = TradingPair().initWithBaseID(bitasset_data.getString("asset_id"), short_backing_asset_id)
        _feedPriceInfo = _tradingPair!!.calcShowFeedInfo(jsonArrayfrom(bitasset_data))

        //  2、计算清算价格以及总清算量等信息
        _nTotalSettlementAmount = calcTotalSettlementAmounts(data_array.getJSONArray(2), bitasset_data, _feedPriceInfo)

        //  3、抵押单列表
        var n_left_settlement = _nTotalSettlementAmount
        val n_zero = BigDecimal.ZERO
        val dataCallOrders = JSONArray()
        for (callorder in data_array.getJSONArray(0).forin<JSONObject>()) {
            val n_collateral = bigDecimalfromAmount(callorder!!.getString("collateral"), _tradingPair!!._quotePrecision)
            val n_debt = bigDecimalfromAmount(callorder.getString("debt"), _tradingPair!!._basePrecision)
            val will_be_settlement = n_left_settlement > n_zero
            dataCallOrders.put(JSONObject().apply {
                put("callorder", callorder)
                put("n_collateral", n_collateral)
                put("n_debt", n_debt)
                put("will_be_settlement", will_be_settlement)
            })
            //  递减
            n_left_settlement = n_left_settlement.subtract(n_collateral)
        }

        //  计算MCR
        val mcr = bitasset_data.getJSONObject("current_feed").getString("maintenance_collateral_ratio")
        _mcr = bigDecimalfromAmount(mcr, 3)

        //  刷新UI - 当前喂价
        val short_backing_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(short_backing_asset_id)
        val str_feed_price = if (_feedPriceInfo != null) _feedPriceInfo!!.toPriceAmountString() else "--"
        _currentView!!.findViewById<TextView>(R.id.label_txt_curr_feed).text = String.format("%s %s %s/%s",
                resources.getString(R.string.kVcRankCurrentFeedPrice),
                str_feed_price,
                _curr_asset.getString("symbol"),
                short_backing_asset.getString("symbol"))

        //  列表
        val lay = _currentView!!.findViewById<LinearLayout>(R.id.layout_fragment_of_diya_ranking_cny)
        lay.removeAllViews()

        if (dataCallOrders.length() > 0) {
            for (json in dataCallOrders.forin<JSONObject>()) {
                createCell(lay, _ctx!!, json!!)
            }
        } else {
            lay.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, R.string.kVcTipsNoCallOrder.xmlstring(_ctx!!)))
        }
    }

    /**
     *  (private) 计算总清算量
     */
    private fun calcTotalSettlementAmounts(settlement_orders: JSONArray, bitasset_data: JSONObject, feed_price: BigDecimal?): BigDecimal {
        var n_total_settle_amount = BigDecimal.ZERO
        if (feed_price != null && feed_price > BigDecimal.ZERO) {
            //  获取清算资产信息
            val settle_asset = _curr_asset
            val settle_asset_precision = settle_asset.getInt("precision")
            //  获取背书资产信息
            val options = bitasset_data.getJSONObject("options")
            val short_backing_asset_id = options.getString("short_backing_asset")
            val sba_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(short_backing_asset_id)
            val sba_asset_precision = sba_asset.getInt("precision")
            //  获取强清补偿系数
            val n_one = BigDecimal.ONE
            val n_force_settlement_offset_percent = bigDecimalfromAmount(options.getString("force_settlement_offset_percent"), 4)
            val n_force_settlement_offset_percent_add1 = n_force_settlement_offset_percent.add(BigDecimal.ONE)

            //  计算清算价格 = 喂价 * （1 + 补偿系数）
            val n_settle_price = n_force_settlement_offset_percent_add1.multiply(feed_price)

            //  计算清算总金额
            var n_settle_total = BigDecimal.ZERO
            for (settle_order in settlement_orders.forin<JSONObject>()) {
                val n_balance = bigDecimalfromAmount(settle_order!!.getJSONObject("balance").getString("amount"), settle_asset_precision)
                n_settle_total = n_settle_total.add(n_balance)
            }
            n_total_settle_amount = ModelUtils.calculateAverage(n_settle_total, n_settle_price, sba_asset_precision)
        }
        return n_total_settle_amount
    }

    private fun createCell(layout: LinearLayout, ctx: Context, jsonitem: JSONObject) {
        val callorder = jsonitem.getJSONObject("callorder")

        //  准备数据
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val account = chainMgr.getChainObjectByID(callorder.getString("borrower"))

        val call_price = callorder.getJSONObject("call_price")
        val coll_asset = chainMgr.getChainObjectByID(call_price.getJSONObject("base").getString("asset_id"))
        val debt_asset = chainMgr.getChainObjectByID(call_price.getJSONObject("quote").getString("asset_id"))

        val will_be_settlement = jsonitem.optBoolean("will_be_settlement")
        val n_coll = jsonitem.get("n_collateral") as BigDecimal
        val n_debt = jsonitem.get("n_debt") as BigDecimal

        //  计算强平触发价
        val str_trigger_price = OrgUtils.calcSettlementTriggerPrice(callorder.getString("debt"), callorder.getString("collateral"),
                debt_asset.getInt("precision"),
                coll_asset.getInt("precision"),
                _mcr!!, false, null, true).toPriceAmountString()

        //  计算抵押率
        val ratio_string = if (_feedPriceInfo != null) {
            val n_ratio = BigDecimal.valueOf(100.0).multiply(n_coll).multiply(_feedPriceInfo!!).divide(n_debt, 2, BigDecimal.ROUND_UP)
            "${n_ratio.toPlainString()}%"
        } else {
            "--%"
        }

        //  构造UI
        val cell = LinearLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            orientation = LinearLayout.VERTICAL
            setPadding(0, 6.dp, 0, 6.dp)

            //  账号名 + 清算中标记（可选） -> 抵押率
            val line01 = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 32.dp).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
                orientation = LinearLayout.HORIZONTAL

                // 左边
                addView(LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 7f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                    addView(TextView(_ctx).apply {
                        text = account.getString("name")
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                        gravity = Gravity.CENTER
                        setPadding(0, 0, 4.dp, 0)
                    })
                    //  清算中标记
                    if (will_be_settlement) {
                        addView(TextView(_ctx).apply {
                            text = resources.getString(R.string.kVcRankFlagWillSettlement)
                            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                            setTextColor(resources.getColor(R.color.theme01_textColorMain))
                            background = resources.getDrawable(R.drawable.flag_settlement)
                            gravity = Gravity.CENTER.or(Gravity.CENTER_VERTICAL)
                            setPadding(4.dp, 1.dp, 4.dp, 1.dp)
                        })
                    }
                })
                // 右边
                addView(LinearLayout(_ctx).apply {
                    val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 3f)
                    _layout_params.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                    layoutParams = _layout_params
                    gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                    addView(TextView(_ctx).apply {
                        text = ratio_string
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        setTextColor(resources.getColor(R.color.theme01_tintColor))
                        gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                    })
                })
            }
            addView(line01)

            //  借款金额、抵押物、强平触发价标题
            val line02 = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
                orientation = LinearLayout.HORIZONTAL
                // 左边
                addView(LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                    addView(TextView(_ctx).apply {
                        text = String.format("%s(%s)", resources.getString(R.string.kVcRankDebt), debt_asset.getString("symbol"))
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorGray))
                        gravity = Gravity.LEFT
                    })
                })
                // 中间
                addView(LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                    addView(TextView(_ctx).apply {
                        text = String.format("%s(%s)", resources.getString(R.string.kVcRankColl), coll_asset.getString("symbol"))
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorGray))
                        gravity = Gravity.CENTER
                    })
                })
                // 右边
                addView(LinearLayout(_ctx).apply {
                    val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    layoutParams = _layout_params
                    gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                    addView(TextView(_ctx).apply {
                        text = resources.getString(R.string.kVcRankCallPrice)
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    })
                })
            }
            addView(line02)

            //  借款金额、抵押物、强平触发价值
            val line03 = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
                orientation = LinearLayout.HORIZONTAL

                // 左边
                addView(LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                    addView(TextView(_ctx).apply {
                        text = n_debt.toPlainString()
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                        gravity = Gravity.LEFT
                    })
                })

                // 中间
                addView(LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                    addView(TextView(_ctx).apply {
                        text = n_coll.toPlainString()
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                        gravity = Gravity.CENTER
                    })
                })
                // 右边
                addView(LinearLayout(_ctx).apply {
                    val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    layoutParams = _layout_params
                    gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                    addView(TextView(_ctx).apply {
                        text = str_trigger_price
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    })
                })
            }
            addView(line03)
        }

        //  线
        val line = View(ctx).apply {
            setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(1.0f))
        }

        val layout_row = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            addView(cell)
            addView(line)
            setOnClickListener {
                activity!!.viewUserAssets(callorder.getString("borrower"))
            }
        }

        layout.addView(layout_row)
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        super.onCreateView(inflater, container, savedInstanceState)
        _ctx = inflater.context
        val v: View = inflater.inflate(R.layout.fragment_margin_ranking, container, false)
        v.findViewById<ImageView>(R.id.tip_link_feedprice).setOnClickListener {
            VcUtils.gotoQaView(activity!!, "qa_feedprice", resources.getString(R.string.kVcTitleWhatIsFeedPrice))
        }
        _currentView = v
        //  refresh UI
        if (_waiting_draw_infos != null) {
            val data_array = _waiting_draw_infos!!
            _waiting_draw_infos = null
            onQueryCallOrderDataResponsed(data_array)
        }
        return v
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
