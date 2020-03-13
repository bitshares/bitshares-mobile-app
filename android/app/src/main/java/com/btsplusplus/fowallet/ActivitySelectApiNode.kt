package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_select_api_node.*
import org.json.JSONArray
import org.json.JSONObject

class ActivitySelectApiNode : BtsppActivity() {

    lateinit var _layout_node_list: LinearLayout
    var _checked_node_img: ImageView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_select_api_node)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()


        _layout_node_list = node_list_from_select_api_node

        refreshUI()

        // 新增
        button_add_from_select_api_node.setOnClickListener {
            goTo(ActivityAddNewApiNode::class.java, true)
        }

        // 返回
        layout_back_from_select_api_node.setOnClickListener { finish() }

    }

    private fun refreshUI(){
        val _ctx = this

        // REMARK 测试数据
        val node_list = JSONArray().apply {
            for (i in 0 until 10){
                put(JSONObject().apply {
                    put("node_name","中国杭州节点 - BTS++${i}")
                    put("node_url","http://xxxxx.xxxx.com")
                    put("is_custom",i == 5)
                })
            }
        }

        var i = 0
        _layout_node_list.removeAllViews()
        _layout_node_list.addView(ViewLine(this, 0.dp, 10.dp))
        node_list.forEach<JSONObject> {
            val data = it!!

            val layout_parent = LinearLayout(_ctx)
            layout_parent.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                setMargins(0,0,0,10.dp)
            }

            // 左: node 名称 和 url
            val layout_left = LinearLayout(_ctx)
            layout_left.orientation = LinearLayout.VERTICAL
            layout_left.layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,1.0f).apply {
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
            }

            val layout_text_and_label = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                orientation = LinearLayout.HORIZONTAL

                val tv_node_name = TextView(_ctx).apply {
                    text = data.getString("node_name")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                }
                addView(tv_node_name)

                if (data.getBoolean("is_custom")) {
                    val tv_custom_label = TextView(_ctx).apply {
                        layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                            setMargins(5.dp,0,0,0)
                        }
                        text = "自定义"
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 9.0f)
                        gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                        background = resources.getDrawable(R.drawable.border_text_view)
                    }
                    addView(tv_custom_label)
                }
            }

            val tv_node_url = TextView(_ctx).apply {
                text = data.getString("node_url")
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            }

            // 右: 勾选图片
            val layout_right = LinearLayout(this)
            layout_right.layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
            }
            layout_right.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

            val check_image = ImageView(_ctx)
            check_image.setImageResource(R.drawable.ic_btn_check)
            check_image.tag = "node_${i}"
            check_image.visibility = View.INVISIBLE



            layout_parent.setOnClickListener {
                onNodeClick(check_image)
            }

            layout_left.addView(layout_text_and_label)
            layout_left.addView(tv_node_url)

            layout_right.addView(check_image)

            layout_parent.addView(layout_left)
            layout_parent.addView(layout_right)
            _layout_node_list.addView(layout_parent)
            _layout_node_list.addView(ViewLine(this, 0.dp, 10.dp))

            i++
        }

    }

    private fun onNodeClick(node_image: ImageView){

        if (_checked_node_img != null) {
            _checked_node_img!!.visibility = View.INVISIBLE
        }

//        val image = _layout_node_list.findViewWithTag<ImageView>("node_${index}")
        node_image.visibility = View.VISIBLE
        _checked_node_img = node_image

    }
}
