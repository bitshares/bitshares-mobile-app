package com.btsplusplus.fowallet

import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_select_api_node.*
import org.json.JSONArray
import org.json.JSONObject

const val kActionOpSwitch = 0       //  切换到该节点
const val kActionOpRemoveNode = 1   //  移除该节点（仅自定义节点可移除）
const val kActionOpCopyURL = 2      //  复制节点URL

class ActivitySelectApiNode : BtsppActivity() {

    private var _data_array = JSONArray()
    private var _user_config = JSONObject()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_select_api_node)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  初始化数据
        val network_infos = ChainObjectManager.sharedChainObjectManager().getCfgNetWorkInfos()
        _data_array.putAll(network_infos.getJSONArray("ws_node_list"))
        val user_connfig = SettingManager.sharedSettingManager().getUseConfig(kSettingKey_ApiNode) as? JSONObject
        if (user_connfig != null) {
            _user_config = user_connfig
            val list = _user_config.optJSONArray(kSettingKey_ApiNode_CustomList)
            if (list != null) {
                _data_array.putAll(list)
            }
        }

        //  刷新UI
        _refresh_ui(_data_array)

        //  事件 - 新增
        button_add_from_select_api_node.setOnClickListener { _onAddNewNodeClicked() }

        //  事件 - 随机选择
        layout_random.setOnClickListener { _onNodeCellClicked(null, img_icon_arrow_random) }

        //  事件 - 返回
        layout_back_from_select_api_node.setOnClickListener { finish() }
    }

    private fun _onNodeCellClicked(node: JSONObject?, arrow_view: ImageView) {
        val self = this
        val current_node = _user_config.optJSONObject(kSettingKey_ApiNode_Current)
        if (node == null) {
            //  当前默认就是随机选择节点，直接返回。
            if (current_node == null) {
                return
            }
            //  准备切换为随机选择
            switchToRandomSelectCore().then { success ->
                if (success != null && success as Boolean) {
                    //  切换成功
                    onSetNewCurrentNode(null)
                } else {
                    //  重新随机初始化网络失败
                    showToast(resources.getString(R.string.tip_network_error))
                }
            }
        } else {
            //  点击某个节点
            val oplist = JSONArray()
            val bCurrentUsingNode = current_node != null && current_node.getString("url") == node.getString("url")
            //  OP - 设置为当前节点
            if (!bCurrentUsingNode) {
                oplist.put(JSONObject().apply {
                    put("name", self.resources.getString(R.string.kSettingApiOpSetAsCurrent))
                    put("type", kActionOpSwitch)
                })
            }
            //  OP - 移除
            if (node.optBoolean("_is_custom")) {
                oplist.put(JSONObject().apply {
                    put("name", self.resources.getString(R.string.kSettingApiOpRemoveNode))
                    put("type", kActionOpRemoveNode)
                })
            }
            //  OP - 复制
            oplist.put(JSONObject().apply {
                put("name", self.resources.getString(R.string.kSettingApiOpCopyURL))
                put("type", kActionOpCopyURL)
            })
            //  显示 - 操作列表
            ViewSelector.show(self, "", oplist, "name") { index: Int, _: String ->
                val opitem = oplist.getJSONObject(index)
                when (opitem.getInt("type")) {
                    kActionOpSwitch -> {
                        val mask = ViewMask(resources.getString(R.string.kSettingApiSwitchTips), this).apply { show() }
                        GrapheneConnection.checkNodeStatus(node, 0, 10, true).then {
                            mask.dismiss()
                            val node_status = it as JSONObject
                            if (node_status.optBoolean("connected")) {
                                //  更新设置
                                onSetNewCurrentNode(node)
                                //  更新当前节点
                                GrapheneConnectionManager.sharedGrapheneConnectionManager().switchTo(node_status.get("conn_obj") as GrapheneConnection)
                            } else {
                                showToast(resources.getString(R.string.kSettingApiSwitchFailed))
                            }
                            return@then null
                        }
                    }
                    kActionOpRemoveNode -> {
                        if (bCurrentUsingNode) {
                            showToast(resources.getString(R.string.kSettingApiRemoveInUsing))
                        } else {
                            _onActionRemoveNodeClicked(node)
                        }
                    }
                    kActionOpCopyURL -> {
                        val value = node.getString("url")
                        if (Utils.copyToClipboard(this, value)) {
                            showToast(resources.getString(R.string.kVcDWTipsCopyOK))
                        }
                    }
                    else -> assert(false)
                }
            }
        }
    }

    private fun onSetNewCurrentNode(node: JSONObject?) {
        if (node != null) {
            //  选择：新节点
            _user_config.put(kSettingKey_ApiNode_Current, node)
        } else {
            //  选择：随机 - 移除之前的节点
            _user_config.remove(kSettingKey_ApiNode_Current)
        }
        SettingManager.sharedSettingManager().setUseConfig(kSettingKey_ApiNode, _user_config)
        //  刷新UI
        _refresh_ui(_data_array)
    }

    /**
     *  (private) 切换到 - 随机选择节点，切换成功返回 Promise YES，否则返回 Promise NO。
     */
    private fun switchToRandomSelectCore(): Promise {
        val p = Promise()
        val mask = ViewMask(resources.getString(R.string.kSettingApiSwitchTips), this).apply { show() }
        val connMgr = GrapheneConnectionManager()
        connMgr.Start(resources.getString(R.string.serverWssLangKey), force_use_random_node = true).then {
            mask.dismiss()
            GrapheneConnectionManager.replaceWithNewGrapheneConnectionManager(connMgr)
            p.resolve(true)
            return@then null
        }.catch {
            mask.dismiss()
            p.resolve(false)
        }
        return p
    }

    /**
     *  (private) 删除节点
     */
    private fun _onActionRemoveNodeClicked(remove_node: JSONObject) {
        val remove_url = remove_node.getString("url")
        val list = _user_config.getJSONArray(kSettingKey_ApiNode_CustomList)
        var idx = 0
        for (node in list.forin<JSONObject>()) {
            if (node!!.getString("url") == remove_url) {
                list.remove(idx)
                //  使用中的节点不可删除。
                assert(_user_config.optJSONObject(kSettingKey_ApiNode_Current) == null ||
                        _user_config.getJSONObject(kSettingKey_ApiNode_Current).getString("url") != remove_url)
                //  保存
                SettingManager.sharedSettingManager().setUseConfig(kSettingKey_ApiNode, _user_config)
                break
            }
            ++idx
        }
        //  刷新UI
        idx = 0
        for (node in _data_array.forin<JSONObject>()) {
            if (node!!.getString("url") == remove_url) {
                _data_array.remove(idx)
                break
            }
            ++idx
        }
        _refresh_ui(_data_array)
    }

    /**
     *  (private) 新增API节点
     */
    private fun _onAddNewNodeClicked() {
        val url_hash = JSONObject()
        for (node in _data_array.forin<JSONObject>()) {
            url_hash.put(node!!.getString("url"), true)
        }
        val result_promise = Promise()
        goTo(ActivityAddNewApiNode::class.java, true, args = JSONObject().apply {
            put("url_hash", url_hash)
            put("result_promise", result_promise)
        })
        result_promise.then { result ->
            val new_node = result as? JSONObject
            if (new_node != null) {
                assert(!url_hash.has(new_node.getString("url")))
                //  添加到列表
                var list = _user_config.optJSONArray(kSettingKey_ApiNode_CustomList)
                if (list == null) {
                    list = JSONArray()
                    _user_config.put(kSettingKey_ApiNode_CustomList, list)
                }
                list.put(new_node)
                SettingManager.sharedSettingManager().setUseConfig(kSettingKey_ApiNode, _user_config)
                //  刷新UI
                _data_array.put(new_node)
                _refresh_ui(_data_array)
            }
        }
    }

    private fun _refresh_ui(data_array: JSONArray) {
        //  描绘随机选择后面的箭头
        val current_node = _user_config.optJSONObject(kSettingKey_ApiNode_Current)
        if (current_node != null) {
            img_icon_arrow_random.visibility = View.INVISIBLE
        } else {
            img_icon_arrow_random.visibility = View.VISIBLE
        }

        //  描绘所有节点
        val ctx = this
        layout_nodelist_container.let { container ->
            //  清空
            container.removeAllViews()
            container.addView(ViewLine(this, 0.dp, 10.dp))
            //  循环描绘
            data_array.forEach<JSONObject> {
                val node = it!!

                //  数据：当前节点名
                val namekey = node.optString("namekey", "")
                val node_name = if (namekey.isNotEmpty()) {
                    resources.getString(resources.getIdentifier(namekey, "string", packageName))
                } else {
                    node.optString("location", null) ?: node.optString("name")
                }

                //  数据：是否选中当前节点
                val bCurrentUsingNode = current_node != null && current_node.getString("url") == node.getString("url")

                //  UI - CELL容器
                val layout_parent = LinearLayout(ctx)
                layout_parent.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0, 0, 0, 10.dp)
                }

                // 左: node 名称 和 url
                val layout_left = LinearLayout(ctx)
                layout_left.orientation = LinearLayout.VERTICAL
                layout_left.layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 9.0f).apply {
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                }

                val layout_text_and_label = LinearLayout(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    orientation = LinearLayout.HORIZONTAL

                    val tv_node_name = TextView(ctx).apply {
                        text = node_name
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                        gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    }
                    addView(tv_node_name)
                    //  自定义标签
                    if (node.optBoolean("_is_custom")) {
                        val tv_custom_label = TextView(ctx).apply {
                            layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                                setMargins(4.dp, 0, 0, 0)
                            }
                            text = resources.getString(R.string.kSettingApiCellCustomFlag)
                            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
                            setTextColor(resources.getColor(R.color.theme01_textColorMain))
                            gravity = Gravity.CENTER_VERTICAL
                            setPadding(4.dp, 1.dp, 4.dp, 1.dp)
                            background = resources.getDrawable(R.drawable.border_text_view)
                        }
                        addView(tv_custom_label)
                    }
                }

                val tv_node_url = TextView(ctx).apply {
                    text = node.getString("url")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                }

                // 右: 勾选图片
                val layout_right = LinearLayout(this)
                layout_right.layoutParams = LinearLayout.LayoutParams(14.dp, 14.dp, 0.5f).apply {
                    gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                }
                layout_right.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                val check_image = ImageView(ctx)
                check_image.setImageResource(R.drawable.ic_btn_check)
                if (bCurrentUsingNode) {
                    check_image.visibility = View.VISIBLE
                } else {
                    check_image.visibility = View.INVISIBLE
                }

                //  事件 - 点击CELL
                layout_parent.setOnClickListener { _onNodeCellClicked(node, check_image) }

                layout_left.addView(layout_text_and_label)
                layout_left.addView(tv_node_url)

                layout_right.addView(check_image)

                layout_parent.addView(layout_left)
                layout_parent.addView(layout_right)
                container.addView(layout_parent)
                container.addView(ViewLine(this, 0.dp, 10.dp))
            }
        }
    }
}
