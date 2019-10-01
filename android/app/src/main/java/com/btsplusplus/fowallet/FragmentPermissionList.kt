package com.btsplusplus.fowallet

import android.app.Activity
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import org.json.JSONArray
import org.json.JSONObject

// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"


/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentPermissionList.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentPermissionList.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentPermissionList : BtsppFragment() {
    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var listener: OnFragmentInteractionListener? = null
    private var _ctx: Context? = null
    private var _view: View? = null
    private var _data: JSONArray? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            param1 = it.getString(ARG_PARAM1)
            param2 = it.getString(ARG_PARAM2)
        }
    }

    //  刷新界面
    private fun refreshUI(){


        var index = 1
        _data!!.forEach<JSONObject> {
            val data = it!!
            val permission_type = data.getInt("permission_type")

            val permission_name = when (permission_type) {
                1 -> "账号权限"
                2 -> "资金权限"
                3 -> "备注权限"
                else -> { // 注意这个块
                    "未知权限"
                }
            }

            val is_remark_permission = permission_type == 3

            val parent_layout = _view!!.findViewById<LinearLayout>(R.id.layout_of_fragment_permission_list)

            // 权限名称 , 阀值
            val layout_title_info = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
                orientation = LinearLayout.HORIZONTAL

                val layout_left = LinearLayout(_ctx).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL

                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,1.0f).apply {
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    }

                    val tv_account_name = TextView(_ctx).apply {
                        layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                            gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                            setMargins(0,0,5.dp,0)
                        }
                        gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                        text = "${index}.${permission_name}"
                    }

                    val iv_edit = ImageView(_ctx).apply {
                        layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                            gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                        }
                        gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                        setImageDrawable(resources.getDrawable(R.drawable.ic_btn_star))
                        scaleType = ImageView.ScaleType.FIT_END

                        setOnClickListener {
                            onEditPermission()
                        }
                    }
                    addView(tv_account_name)
                    addView(iv_edit)
                }
                addView(layout_left)

                // 备注权限不需显示阀值
                if (!is_remark_permission){
                    val layout_right = LinearLayout(_ctx).apply {
                        orientation = LinearLayout.HORIZONTAL
                        gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL

                        layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,1.0f).apply {
                            gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                        }

                        val tv_threshold_name = TextView(_ctx).apply {
                            gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                            text = "阀值"
                            setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        }

                        val tv_threshold_value = TextView(_ctx).apply {
                            gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                            text = data.getInt("threshold_value").toString()
                            setPadding(2.dp,0,0,0)
                            setTextColor(resources.getColor(R.color.theme01_textColorMain))
                            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)

                        }

                        addView(tv_threshold_name)
                        addView(tv_threshold_value)
                    }
                    addView(layout_right)
                }


            }
            parent_layout.addView(layout_title_info)

            // 管理者账号/公钥  权重 (备注权限不需要)
            if (!is_remark_permission){
                val layout_account_title_info = LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                        setMargins(0, 10.dp, 0,5.dp)
                    }
                    orientation = LinearLayout.HORIZONTAL

                    val layout_left = LinearLayout(_ctx).apply {
                        orientation = LinearLayout.HORIZONTAL
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL

                        layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1.0f).apply {
                            gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                        }

                        val tv_title_name = TextView(_ctx).apply {
                            text = "管理者账号/公钥"
                            setTextColor(resources.getColor(R.color.theme01_textColorGray))
                            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        }

                        addView(tv_title_name)

                    }

                    val layout_right = LinearLayout(_ctx).apply {
                        orientation = LinearLayout.HORIZONTAL
                        gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL

                        layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1.0f).apply {
                            gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                        }

                        val tv_weight_name = TextView(_ctx).apply {
                            text = "权重"
                            setTextColor(resources.getColor(R.color.theme01_textColorGray))
                            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                        }

                        addView(tv_weight_name)

                    }



                    addView(layout_left)
                    addView(layout_right)
                }
                parent_layout.addView(layout_account_title_info)

                data.getJSONArray("list").forEach<JSONObject> {
                    val data = it!!

                    val layout_permission_weight = LinearLayout(_ctx).apply {
                        layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                            setMargins(0, 0.dp, 0, 5.dp)
                        }
                        orientation = LinearLayout.HORIZONTAL


                        val layout_left = LinearLayout(_ctx).apply {
                            orientation = LinearLayout.HORIZONTAL
                            gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL

                            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 4.3f).apply {
                                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                            }
                            val tv_admin_public_key = TextView(_ctx).apply {
//                                text = data.getString("admin_public_key")
                                text = "admin_public_key3212343243242323443224342323423423423243234243234243234234343242342342343423234324423342234234423234234432"
                                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                                setSingleLine(true)
                                maxLines = 1
                                ellipsize = TextUtils.TruncateAt.END
                            }
                            addView(tv_admin_public_key)
                        }

                        val layout_right = LinearLayout(_ctx).apply {
                            orientation = LinearLayout.HORIZONTAL
                            gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL

                            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1.0f).apply {
                                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                            }

                            val tv_weight = TextView(_ctx).apply {
                                text = data.getInt("weight").toString()
                                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                            }
                            val tv_weight_percent = TextView(_ctx).apply {
                                text = data.getString("weight_percent")
                                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                            }
                            addView(tv_weight)
                            addView(tv_weight_percent)
                        }

                        addView(layout_left)
                        addView(layout_right)
                    }
                    parent_layout.addView(layout_permission_weight)
                }
            }

            // 备注权限
            if (is_remark_permission){
                val tv_weight = TextView(_ctx).apply {
                    text = data.getString("remark")
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                    setSingleLine(true)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                }
                parent_layout.addView(tv_weight)
            }

            parent_layout.addView(ViewLine(_ctx!!,10.dp,10.dp))

            index++
        }

    }

    private fun onEditPermission(){
        (_ctx as Activity).goTo(ActivityPermissionEdit::class.java, true)
    }


    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_permission_list, container, false)

        getData()

        return _view
    }

    private fun getData(){
        // Todo: 获取权限数据

        _data = JSONArray().apply {
            for (n in 1 until 4) {
                val json = JSONObject().apply {

                    put("permission_type", n)
                    put("threshold_value", 1)

                    val list = JSONArray().apply {
                        for (i in 1 until 20) {
                            var obj = JSONObject().apply {
                                put("admin_public_key", "btspp-daemon${i}")
                                put("weight", i)
                                put("weight_percent", "${i}%")
                            }
                            put(obj)
                        }
                    }
                    put("list", list)
                    put("remark","BTS12345678943213456782124356752345675432456432456754324567234567")
                }

                put(json)
            }
        }
        onDate()
    }

    private fun onDate(){
        refreshUI()
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

    companion object {
        /**
         * Use this factory method to create a new instance of
         * this fragment using the provided parameters.
         *
         * @param param1 Parameter 1.
         * @param param2 Parameter 2.
         * @return A new instance of fragment FragmentPermissionList.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentPermissionList().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
