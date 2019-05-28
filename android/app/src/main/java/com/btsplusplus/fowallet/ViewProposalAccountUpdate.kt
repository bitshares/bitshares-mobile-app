package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.xmlstring
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONObject

class ViewProposalAccountUpdate : LinearLayout {

    var _ctx: Context
    var _item: JSONObject
    var _useBuyColorForTitle: Boolean
    var _useNormalDescLabel = true          //  是否使用普通的desc描述字段

    private val content_fontsize = 11.0f

    constructor(ctx: Context, item: JSONObject, useBuyColorForTitle: Boolean) : super(ctx) {
        _ctx = ctx
        _item = item
        _useBuyColorForTitle = useBuyColorForTitle
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_params.topMargin = 10
        this.layoutParams = layout_params
        this.orientation = LinearLayout.VERTICAL

        createUI()
    }

    private fun createUI(): LinearLayout {

        val opdata = _item.getJSONObject("opdata")
        val opaccount = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(opdata.getString("account"))

        val new_owner = opdata.optJSONObject("owner")
        val new_active = opdata.optJSONObject("active")
        val new_options = opdata.optJSONObject("new_options")

        val uidata = _item.getJSONObject("uidata")

        // 第一行 提案名称 【危险操作】
        val layout_wrap = LinearLayout(_ctx)
        layout_wrap.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
        layout_wrap.orientation = LinearLayout.HORIZONTAL
        layout_wrap.gravity = Gravity.CENTER_VERTICAL
        layout_wrap.apply {
            val tv1 = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                if (_useBuyColorForTitle) {
                    setTextColor(resources.getColor(R.color.theme01_buyColor))
                } else {
                    val _color = uidata.getInt("color")
                    setTextColor(resources.getColor(_color))
                }
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                paint.isFakeBoldText = true
                text = uidata.getString("name")
            }
            addView(tv1)
            //  危险提示标签
            if (new_owner != null || new_active != null) {
                val tv2 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        setMargins(5.dp, 0.dp, 0.dp, 0.dp)
                        setPadding(5.dp, 0, 5.dp, 0)
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    }
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    setBackgroundColor(resources.getColor(R.color.theme01_sellColor))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10.0f)
                    paint.isFakeBoldText = true
                    text = R.string.kOpDetailFlagDangerous.xmlstring(_ctx)
                }
                addView(tv2)
            }
        }
        addView(layout_wrap)

        //  第二行 特殊View or 没有任何更新。
        //  1、所有者权限
        var _viewPermissionOwner: LinearLayout? = null
        var _viewPermissionActive: LinearLayout? = null
        var _viewPermissionMemoKey: LinearLayout? = null
        var _viewVotingInfos: LinearLayout? = null
        if (new_owner != null) {
            _viewPermissionOwner = ViewProposalAccountUpdatePermissionOwner(_ctx).initWithPermission(opaccount.getJSONObject("owner"), new_owner, R.string.kOpDetailPermissionOwner.xmlstring(_ctx))
            addView(_viewPermissionOwner)
        }

        //  2、资金权限
        if (new_active != null) {
            _viewPermissionActive = ViewProposalAccountUpdatePermissionOwner(_ctx).initWithPermission(opaccount.getJSONObject("active"), new_active, R.string.kOpDetailPermissionActive.xmlstring(_ctx))
            addView(_viewPermissionActive)
        }

        if (new_options != null) {
            val old_options = opaccount.getJSONObject("options")

            //  3、备注权限
            val old_memo_key = old_options.getString("memo_key")
            val new_memo_key = new_options.getString("memo_key")
            if (old_memo_key != new_memo_key) {
                _viewPermissionMemoKey = ViewProposalAccountUpdateMemoKey(_ctx).initWithOldMemo(old_memo_key, new_memo_key, R.string.kOpDetailPermissionMemo.xmlstring(_ctx))
                addView(_viewPermissionMemoKey)
            }

            //  4、投票信息（包括代理）
            val showLinesInfos = ViewProposalAccountUpdateVoting.calcLineInfos(old_options, new_options)
            if (showLinesInfos.length() > 0) {
                _viewVotingInfos = ViewProposalAccountUpdateVoting(_ctx).initWithOptions(showLinesInfos)
                addView(_viewVotingInfos)
            }
        }

        if (_viewPermissionOwner != null || _viewPermissionActive != null || _viewPermissionMemoKey != null || _viewVotingInfos != null) {
            //  REMARK ios 有初始化需要隐藏 ，安卓没初始化
            _useNormalDescLabel = false
        } else {
            //  normal desc line
            val tv2 = TextView(_ctx)
            tv2.text = uidata.getString("desc")
            tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
            tv2.setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
            tv2.setPadding(0, 10, 0, 0)
            addView(tv2)
        }

        return this
    }
}