package com.btsplusplus.fowallet

import android.app.AlertDialog
import android.content.Context
import android.view.WindowManager
import bitshares.dp
import android.view.Display



class ViewSelector {

    companion object {

        fun create(ctx: Context, title: String, list: Array<String>, callback: (index: Int, result: String) -> Unit) : AlertDialog {
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
            return builder.create()
        }

        fun show(ctx: Context, title: String, list: Array<String>, callback: (index: Int, result: String) -> Unit) : AlertDialog {
            val dig = ViewSelector.create(ctx,title,list,callback)

            // Todo 修改窗口高度
//            val params : WindowManager.LayoutParams  = dig.getWindow().getAttributes();
//            params.height = 20.dp
//            dig.getWindow().setAttributes(params)

            dig.show()
            return dig
        }
    }
}