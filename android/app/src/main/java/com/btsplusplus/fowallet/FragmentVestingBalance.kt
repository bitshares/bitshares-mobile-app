package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import bitshares.*
import com.btsplusplus.fowallet.ViewEx.TextViewEx
import org.json.JSONArray
import org.json.JSONObject

//import org.bitshares.app.R

// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentVestingBalance.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentVestingBalance.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentVestingBalance : BtsppFragment() {

    private var _ctx: Context? = null
    private lateinit var _data: JSONArray

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {

        }
    }

    override fun onInitParams(args: Any?) {
        _data = args as JSONArray

    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        _ctx = inflater.context

        val parent_layout = ScrollView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_MATCH)
        }

        val layout = LinearLayout(_ctx)
        val layout_params = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_MATCH)
        layout.setPadding(10.dp,0,10.dp,0)
        layout.orientation = LinearLayout.VERTICAL
        layout.layoutParams = layout_params

        _data.forEach<JSONObject> {
            val balance = it!!.getString("balance")
            val total_amount = it!!.getString("total_amount")
            val unfreeze_number = it!!.getString("unfreeze_number")
            val unfreeze_cycle = it!!.getString("unfreeze_cycle")

            // line1
            val layout_line1 = LinearLayout(_ctx)
            val layout_line1_params = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
            layout_line1_params.setMargins(0,10.dp,0,0)
            layout_line1.layoutParams = layout_line1_params
            val tv_balance = TextViewEx(_ctx!!,"余额 #${balance}",color = R.color.theme01_textColorMain, gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL)
            layout_line1.addView(tv_balance)
            if (true) {
                val tv_pickup = TextViewEx(_ctx!!,"提取",color = R.color.theme01_textColorHighlight,gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL, width = LLAYOUT_MATCH)
                layout_line1.addView(tv_pickup)

                // click event
                tv_pickup.setOnClickListener{

                }
            }

            // line2
            val layout_line2 = LinearLayout(_ctx)
            val layout_line2_params = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
            layout_line2_params.setMargins(0,10.dp,0,0)
            layout_line2.layoutParams = layout_line2_params
            val tv_total_amount = TextViewEx(_ctx!!,"总数量(BTS)",color = R.color.theme01_textColorGray ,width = 0.dp, weight = 1.0f,gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL, dp_size = 11.0f)
            val tv_unfreeze_amount = TextViewEx(_ctx!!,"已解冻数量(BTS)",color = R.color.theme01_textColorGray ,width = 0.dp, weight = 1.0f,gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL,dp_size = 11.0f)
            val tv_unfreeze_cycle = TextViewEx(_ctx!!,"解冻周期",color = R.color.theme01_textColorGray ,width = 0.dp, weight = 1.0f,gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL,dp_size = 11.0f)
            layout_line2.addView(tv_total_amount)
            layout_line2.addView(tv_unfreeze_amount)
            layout_line2.addView(tv_unfreeze_cycle)

            // line3
            val layout_line3 = LinearLayout(_ctx)
            val layout_line3_params = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
            layout_line3_params.setMargins(0,10.dp,0,10.dp)
            layout_line3.layoutParams = layout_line3_params
            val tv_total_amount_value = TextViewEx(_ctx!!,total_amount,color = R.color.theme01_textColorNormal ,width = 0.dp, weight = 1.0f,gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL,dp_size = 11.0f)
            val tv_unfreeze_amount_value = TextViewEx(_ctx!!,unfreeze_number,color = R.color.theme01_textColorNormal ,width = 0.dp, weight = 1.0f,gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL,dp_size = 11.0f)
            val tv_unfreeze_cycle_value = TextViewEx(_ctx!!,unfreeze_cycle,color = R.color.theme01_textColorNormal ,width = 0.dp, weight = 1.0f,gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL,dp_size = 11.0f)
            layout_line3.addView(tv_total_amount_value)
            layout_line3.addView(tv_unfreeze_amount_value)
            layout_line3.addView(tv_unfreeze_cycle_value)


            layout.addView(layout_line1)
            layout.addView(layout_line2)
            layout.addView(layout_line3)
            layout.addView(ViewLine(_ctx!!))

        }

        parent_layout.addView(layout)

        return parent_layout

    }


}
