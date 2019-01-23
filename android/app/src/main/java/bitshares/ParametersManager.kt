package bitshares

class ParametersManager {
    companion object {
        private var _sharedParametersManager = ParametersManager()

        fun sharedParametersManager(): ParametersManager {
            return _sharedParametersManager
        }
    }

    private var _param_id = 0
    private var _param_map = HashMap<Int, Any?>()

    fun genParams(params: Any?): Int {
        val next_id = ++_param_id
        _param_map[next_id] = params
        return next_id
    }

    fun getParams(param_id: Int): Any? {
        return _param_map[param_id]
    }

    fun delParams(param_id: Int) {
        _param_map.remove(param_id)
    }
}