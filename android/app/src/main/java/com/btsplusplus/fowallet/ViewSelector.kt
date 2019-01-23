package com.btsplusplus.fowallet

import android.app.AlertDialog
import android.content.Context

class ViewSelector {

    companion object {
        fun show(ctx: Context, title: String, list: Array<String>, callback: (index: Int, result: String) -> Unit) {
            val items = list

            val builder = AlertDialog.Builder(ctx, 5)
            builder.setTitle(title)

            builder.setItems(items) { dialog, which ->
                dialog.dismiss()
                callback.invoke(which, items[which])
            }
            builder.setPositiveButton(ctx.resources.getString(R.string.nameCancel)) { dialog, _ ->
                dialog.dismiss()
            }
            builder.create().show()
        }
    }
}