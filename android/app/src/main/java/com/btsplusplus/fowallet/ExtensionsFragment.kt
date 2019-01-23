package com.btsplusplus.fowallet

import android.support.v4.app.Fragment
import bitshares.Utils

fun Fragment.toDp(v: Float): Int {
    return Utils.toDp(v, this.resources)
}

/**
 * 获取对应的 activity
 */
inline fun <reified T> Fragment.getOwner(): T? {
    return activity as? T
}