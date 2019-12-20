package bitshares

import org.json.JSONObject
import java.util.*

class AsyncTaskManager {

    companion object {

        private var _sharedAsyncTaskManager = AsyncTaskManager()

        fun sharedAsyncTaskManager(): AsyncTaskManager {
            return _sharedAsyncTaskManager
        }
    }

    private var _seconds_timer_id = 0
    private var _seconds_timer_hash = JSONObject()

    /**
     *  (public) 启动按秒的定时器。返回定时器ID号。
     */
    fun scheduledSecondsTimer(max_second: Long, callback: (left_ts: Long) -> Unit): Int {
        assert(max_second > 0)
        val startTs = Utils.now_ts()
        val endTs = startTs + max_second
        return scheduledSecondsTimerWithEndTS(endTs, callback)
    }

    fun scheduledSecondsTimerWithEndTS(end_ts: Long, callback: (left_ts: Long) -> Unit): Int {
        assert(end_ts > 0)
        val tid = ++_seconds_timer_id
        val timer_id = tid.toString()

        val timer = Timer()
        _seconds_timer_hash.put(timer_id, timer)

        timer.schedule(object : TimerTask() {
            override fun run() {
                delay_main {
                    _onSecondsTimerTick(end_ts, timer_id, callback)
                }
            }
        }, 1, 1000)

        return tid
    }

    /**
     *  (public) 定时器是否存在
     */
    fun isExistSecondsTimer(tid: Int): Boolean {
        if (tid <= 0) {
            return false
        }
        return _seconds_timer_hash.has(tid.toString())
    }

    /**
     *  (public) 停止定时器
     */
    fun removeSecondsTimer(tid: Int) {
        if (tid > 0) {
            _removeSecondsTimerCore(tid.toString())
        }
    }

    private fun _removeSecondsTimerCore(timer_id: String) {
        val timer = _seconds_timer_hash.opt(timer_id) as? Timer
        if (timer != null) {
            timer.cancel()
            _seconds_timer_hash.remove(timer_id)
        }
    }

    private fun _onSecondsTimerTick(end_ts: Long, timer_id: String, callback: (left_ts: Long) -> Unit) {
        val now_ts = Utils.now_ts()
        val left_ts = end_ts - now_ts

        //  回调
        callback(left_ts)

        //  结束
        if (left_ts <= 0) {
            _removeSecondsTimerCore(timer_id)
        }
    }
}
