package bitshares

import android.os.AsyncTask

class BtsppAsyncTask : AsyncTask<Any?, Int, Any?>() {

    private var _result_promise: Promise? = null
    private var _body: (() -> Unit)? = null

    fun run(body: () -> Unit): Promise {
        _result_promise = Promise()
        _body = body
        this.execute(null)
        return _result_promise!!
    }

    override fun doInBackground(vararg params: Any?): Any? {
        _body?.let { it() }
        return null
    }

    override fun onPostExecute(result: Any?) {
        _result_promise?.resolve(true)
        _result_promise = null
    }
}