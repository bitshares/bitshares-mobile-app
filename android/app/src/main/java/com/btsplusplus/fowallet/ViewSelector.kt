package com.btsplusplus.fowallet

import android.app.AlertDialog
import android.content.Context
import bitshares.forEach
import bitshares.toList
import org.json.JSONArray
import org.json.JSONObject


class ViewSelector {

    companion object {

        fun create(ctx: Context, title: String, list: Array<String>, callback: (index: Int, result: String) -> Unit): AlertDialog {
            val builder = AlertDialog.Builder(ctx, 5)
            builder.setTitle(title)

            builder.setItems(list) { dialog, which ->
                dialog.dismiss()
                callback.invoke(which, list[which])
            }
            builder.setPositiveButton(ctx.resources.getString(R.string.kBtnCancel)) { dialog, _ ->
                dialog.dismiss()
            }
            return builder.create()
        }

        fun show(ctx: Context, title: String, list: Array<String>, callback: (index: Int, result: String) -> Unit): AlertDialog {
            return ViewSelector.create(ctx, title, list, callback).apply { show() }
        }

        fun show(ctx: Context, title: String, array: JSONArray, key: String, callback: (index: Int, result: String) -> Unit): AlertDialog {
            val list = JSONArray()
            array.forEach<JSONObject> { list.put(it!!.getString(key)) }
            return show(ctx, title, list.toList<String>().toTypedArray(), callback)
        }

    }
}