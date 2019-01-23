package bitshares

import android.os.Handler
import android.os.Message

class NotificationCenter {

    companion object {

        private var _sharedNotificationCenter = NotificationCenter()

        fun sharedNotificationCenter(): NotificationCenter {
            return _sharedNotificationCenter
        }
    }

    private var _msg_handlers = mutableMapOf<String, ArrayList<Handler>>()

    /**
     * 订阅
     */
    fun addObserver(name: String, handler: Handler) {
        val handler_list = _msg_handlers.get(name)
        if (handler_list == null) {
            _msg_handlers.put(name, arrayListOf(handler))
        } else {
            handler_list.add(handler)
        }
    }

    /**
     * 移出订阅
     */
    fun removeObserver(name: String, handler: Handler) {
        val handler_list = _msg_handlers.get(name)
        if (handler_list != null) {
            handler_list.remove(handler)
        }
    }

    /**
     * 投递信息给接受订阅者
     */
    fun postNotificationName(name: String, data: Any) {
        val handler_list = _msg_handlers.get(name)
        if (handler_list != null && handler_list.size > 0) {
            val msg = Message.obtain()
            msg.obj = data
            handler_list.forEach { it.sendMessage(msg) }
        }
    }
}
