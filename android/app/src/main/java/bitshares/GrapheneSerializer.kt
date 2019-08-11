package bitshares.serializer

import bitshares.*
import org.json.JSONArray
import org.json.JSONObject

open class T_Base_companion {

    private val _fields = JSONArray()

    /**
     * (public) 编码为二进制流
     */
    fun encode_to_bytes(opdata: Any): ByteArray {
        val io = BinSerializer()
        encode_to_bytes_with_type(this, opdata, io)
        return io.get_data()
    }

    /**
     * (public) 编码为 object 对象。
     */
    fun encode_to_object(opdata: Any): Any {
        return encode_to_object_with_type(this, opdata)!!
    }

    protected fun encode_to_bytes_with_type(optype: T_Base_companion, opdata: Any?, io: BinSerializer) {
        optype.to_byte_buffer(io, opdata)
    }

    protected fun encode_to_object_with_type(optype: T_Base_companion, opdata: Any?): Any? {
        return optype.to_object(opdata)
    }

    protected fun add_field(name: String, optype: T_Base_companion) {
        _fields.put(jsonArrayfrom(name, optype))
    }

    /**
     * (public) 注册可序列化的类型。REMARK：所有复合类型都必须注册，基本类型不用注册。
     */
    fun registerAllType() {
        T_asset.register_subfields()
        T_memo_data.register_subfields()

        T_transfer.register_subfields()
        T_limit_order_create.register_subfields()
        T_limit_order_cancel.register_subfields()
        T_call_order_update.register_subfields()

        T_authority.register_subfields()
        T_account_options.register_subfields()
        T_account_create.register_subfields()
        T_account_update.register_subfields()
        T_account_upgrade.register_subfields()
        T_vesting_balance_withdraw.register_subfields()

        T_op_wrapper.register_subfields()

        T_proposal_create.register_subfields()
        T_proposal_update.register_subfields()
        T_proposal_delete.register_subfields()

        T_asset_update_issuer.register_subfields()

        T_transaction.register_subfields()
        T_signed_transaction.register_subfields()

        T_htlc_create.register_subfields()
        T_htlc_redeem.register_subfields()
        T_htlc_extend.register_subfields()
    }

    open fun register_subfields() {
        assert(false)
    }

    open fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
        assert(_fields.length() > 0)
        _fields.forEach<JSONArray> {
            val field_name = it!!.getString(0)
            val field_type = it.get(1) as T_Base_companion
            val json = opdata as JSONObject
            val value = json.opt(field_name)
            encode_to_bytes_with_type(field_type, value, io)
        }
    }

    open fun to_object(opdata: Any?): Any? {
        if (_fields.length() > 0) {
            val opdata_json = opdata as JSONObject
            val result = JSONObject()
            _fields.forEach<JSONArray> {
                val field_name = it!!.getString(0)
                val field_type = it.get(1) as T_Base_companion
                val value = opdata_json.opt(field_name)
                val obj = encode_to_object_with_type(field_type, value)
                if (obj != null) {
                    result.put(field_name, obj)
                } else {
                    assert(field_type is Tm_optional)
                }
            }
            return result
        } else {
            return opdata
        }
    }
}

open class T_Base {
    companion object : T_Base_companion()
}

/***
 * 以下为基本数据类型。
 */
class T_uint8 : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            when (opdata) {
                is Number -> io.write_u8(opdata.toInt())
                is String -> io.write_u8(opdata.toInt())
                else -> assert(false)
            }
        }
    }
}

class T_uint16 : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            when (opdata) {
                is Number -> io.write_u16(opdata.toInt())
                is String -> io.write_u16(opdata.toInt())
                else -> assert(false)
            }
        }
    }
}

class T_uint32 : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            when (opdata) {
                is Number -> io.write_u32(opdata.toLong())
                is String -> io.write_u32(opdata.toLong())
                else -> assert(false)
            }
        }
    }
}

class T_uint64 : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            //  TODO: Long < u64
            when (opdata) {
                is Number -> io.write_u64(opdata.toLong())
                is String -> io.write_u64(opdata.toLong())
                else -> assert(false)
            }
        }
    }
}

class T_int64 : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            when (opdata) {
                is Number -> io.write_s64(opdata.toLong())
                is String -> io.write_s64(opdata.toLong())
                else -> assert(false)
            }
        }
    }
}

class T_varint32 : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            when (opdata) {
                is Number -> io.write_varint32(opdata.toInt())
                is String -> io.write_varint32(opdata.toInt())
                else -> assert(false)
            }
        }
    }
}

class T_string : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            assert(opdata is String)
            io.write_string(opdata as String)
        }
    }
}

class T_bool : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            assert(opdata is Boolean)
            if (opdata as Boolean) {
                io.write_u8(1)
            } else {
                io.write_u8(0)
            }
        }
    }
}

class T_void : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            assert(false) { "(void) undefined type" }
        }
    }
}

class T_future_extensions : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            assert(false) { "not supported" }
        }
    }
}

class T_object_id_type : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            assert(false) { "not supported" }
        }
    }
}

class T_vote_id : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            val vote_id = opdata as String
            //  TODO:check
            //  v.require_test(/^[0-9]+:[0-9]+$/, object, `vote_id format ${object}`);
            val ary = vote_id.split(':')
            val vote_type = ary[0].toLong()
            val vote_idnum = ary[1].toLong()
            //  v.require_range(0, 0xff, type, `vote type ${object}`);
            //  v.require_range(0, 0xffffff, id, `vote id ${object}`);
            io.write_u32(vote_idnum.shl(8).or(vote_type))
        }
    }
}

class T_public_key : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            assert(opdata is String)
            io.write_public_key(opdata as String)
        }
    }
}

class T_address : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            assert(false) { "not supported" }
        }
    }
}

class T_time_point_sec : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            assert(opdata is Number)
            io.write_u32((opdata as Number).toLong())
        }

        override fun to_object(opdata: Any?): Any? {
            assert(opdata is Number)
            //  格式：2033-06-04T13:03:57
            return Utils.formatBitsharesTimeString((opdata as Number).toLong())
        }
    }
}

/***
 * 以下为动态扩展类型
 */
class Tm_protocol_id_type(name: String) : T_Base_companion() {
    private var _name: String = name

    override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
        //  TODO:check name 和 object_id 类型是否匹配 待处理
        io.write_object_id(opdata as String)
    }

    override fun to_object(opdata: Any?): Any? {
        return opdata
    }
}

class Tm_extension(fields_def: JSONArray) : T_Base_companion() {
    private var _fields_def = fields_def

    override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
        //  统计出现的扩展字段数量
        var field_count = 0
        if (opdata != null) {
            val opdata_json = opdata as JSONObject
            _fields_def.forEach<JSONObject> {
                val fields = it!!
                val field_name = fields.getString("name")
                if (opdata_json.has(field_name)) {
                    ++field_count
                }
            }
        }
        //  写入扩展字段数量
        io.write_varint32(field_count)
        //  写入扩展字段的值
        if (field_count > 0) {
            val opdata_json = opdata as JSONObject
            var idx = 0
            _fields_def.forEach<JSONObject> {
                val fields = it!!
                val obj = opdata_json.opt(fields.getString("name"))
                if (obj != null) {
                    io.write_varint32(idx)
                    encode_to_bytes_with_type(fields.get("type") as T_Base_companion, obj, io)
                }
                ++idx
            }
        }
    }

    override fun to_object(opdata: Any?): Any? {
        val result = JSONObject()
        if (opdata != null) {
            val opdata_json = opdata as JSONObject
            _fields_def.forEach<JSONObject> {
                val fields = it!!
                val field_name = fields.getString("name")
                val obj = opdata_json.opt(field_name)
                if (obj != null) {
                    val value = encode_to_object_with_type(fields.get("type") as T_Base_companion, obj)
                    assert(value != null)
                    result.put(field_name, value)
                }
            }
        }
        return result
    }
}

class Tm_array(optype: T_Base_companion) : T_Base_companion() {
    private var _optype = optype

    override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
        assert(opdata is JSONArray)
        val ary = opdata as JSONArray
        io.write_varint32(ary.length())
        ary.forEach<Any> {
            encode_to_bytes_with_type(_optype, it, io)
        }
    }

    override fun to_object(opdata: Any?): Any? {
        assert(opdata is JSONArray)
        val ary = opdata as JSONArray
        val result = JSONArray()
        ary.forEach<Any> {
            val value = encode_to_object_with_type(_optype, it)
            assert(value != null)
            result.put(value)
        }
        return result
    }
}

class Tm_map(key_optype: T_Base_companion, value_optype: T_Base_companion) : T_Base_companion() {
    private var _key_optype = key_optype
    private var _value_optype = value_optype

    override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
        assert(opdata is JSONArray)
        val ary = opdata as JSONArray
        io.write_varint32(ary.length())
        ary.forEach<JSONArray> {
            val pair = it!!
            assert(pair.length() == 2)
            encode_to_bytes_with_type(_key_optype, pair.get(0), io)
            encode_to_bytes_with_type(_value_optype, pair.get(1), io)
        }
    }

    override fun to_object(opdata: Any?): Any? {
        assert(opdata is JSONArray)
        val ary = opdata as JSONArray
        val result = JSONArray()
        ary.forEach<JSONArray> {
            val pair = it!!
            assert(pair.length() == 2)
            val key_value = encode_to_object_with_type(_key_optype, pair.get(0))
            val value_value = encode_to_object_with_type(_value_optype, pair.get(1))
            assert(key_value != null && value_value != null)
            result.put(jsonArrayfrom(key_value!!, value_value!!))
        }
        return result
    }
}

class Tm_set(optype: T_Base_companion) : T_Base_companion() {
    private var _optype = optype

    override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
        assert(opdata == null || (opdata is JSONArray))
        val ary = if (opdata == null) JSONArray() else opdata as JSONArray
        io.write_varint32(ary.length())
        ary.forEach<Any> {
            encode_to_bytes_with_type(_optype, it, io)
        }
    }

    override fun to_object(opdata: Any?): Any? {
        assert(opdata == null || (opdata is JSONArray))
        val result = JSONArray()
        if (opdata != null) {
            (opdata as JSONArray).forEach<Any> {
                val value = encode_to_object_with_type(_optype, it)
                assert(value != null)
                result.put(value)
            }
        }
        return result
    }
}

class Tm_bytes(size: Int? = null) : T_Base_companion() {
    private var _size = size

    override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
        assert(opdata is ByteArray)
        val bytes = opdata as ByteArray
        if (_size != null) {
            assert(bytes.size == _size!!)
            io.write_bytes(bytes, false)
        } else {
            io.write_bytes(bytes, true)
        }
    }

    override fun to_object(opdata: Any?): Any? {
        assert(opdata is ByteArray)
        val bytes = opdata as ByteArray
        assert(_size == null || bytes.size == _size!!)
        return opdata.hexEncode()
    }
}

class Tm_optional(optype: T_Base_companion) : T_Base_companion() {
    private var _optype = optype

    override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
        if (opdata == null) {
            io.write_u8(0)
        } else {
            io.write_u8(1)
            encode_to_bytes_with_type(_optype, opdata, io)
        }
    }

    override fun to_object(opdata: Any?): Any? {
        if (opdata == null) {
            return null
        } else {
            return encode_to_object_with_type(_optype, opdata)
        }
    }
}

class Tm_static_variant(optypearray: JSONArray) : T_Base_companion() {
    private var _optypearray = optypearray

    override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
        assert(opdata != null && opdata is JSONArray)
        val _opdata = opdata as JSONArray
        assert(opdata.length() == 2)
        val type_id = _opdata.first<Int>()
        assert(type_id!! < _optypearray.length())
        val optype = _optypearray.get(type_id) as T_Base_companion

        //  1、write typeid  2、write opdata
        io.write_varint32(type_id)
        encode_to_bytes_with_type(optype, opdata.last(), io)
    }

    override fun to_object(opdata: Any?): Any? {
        assert(opdata != null && opdata is JSONArray)
        val _opdata = opdata as JSONArray
        assert(opdata.length() == 2)
        val type_id = _opdata.first<Int>()
        assert(type_id!! < _optypearray.length())
        val optype = _optypearray.get(type_id) as T_Base_companion

        return JSONArray().apply {
            put(type_id)
            put(encode_to_object_with_type(optype, opdata.last()))
        }
    }
}

/***
 * 以下为复合数据类型（大部分op都是为复合类型）。
 */
class T_asset : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("amount", T_int64)
            add_field("asset_id", Tm_protocol_id_type("asset"))
        }
    }
}

class T_memo_data : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("from", T_public_key)
            add_field("to", T_public_key)
            add_field("nonce", T_uint64)
            add_field("message", Tm_bytes())
        }
    }
}

class T_transfer : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("from", Tm_protocol_id_type("account"))
            add_field("to", Tm_protocol_id_type("account"))
            add_field("amount", T_asset)
            add_field("memo", Tm_optional(T_memo_data))
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_limit_order_create : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("seller", Tm_protocol_id_type("account"))
            add_field("amount_to_sell", T_asset)
            add_field("min_to_receive", T_asset)
            add_field("expiration", T_time_point_sec)
            add_field("fill_or_kill", T_bool)
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_limit_order_cancel : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("fee_paying_account", Tm_protocol_id_type("account"))
            add_field("order", Tm_protocol_id_type("limit_order"))
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_call_order_update : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("funding_account", Tm_protocol_id_type("account"))
            add_field("delta_collateral", T_asset)
            add_field("delta_debt", T_asset)
            add_field("extensions", Tm_extension(jsonArrayfrom(jsonObjectfromKVS("name", "target_collateral_ratio", "type", T_uint16))))
        }
    }
}

class T_authority : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("weight_threshold", T_uint32)
            add_field("account_auths", Tm_map(Tm_protocol_id_type("account"), T_uint16))
            add_field("key_auths", Tm_map(T_public_key, T_uint16))
            add_field("address_auths", Tm_map(T_address, T_uint16))
        }
    }
}

class T_account_options : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("memo_key", T_public_key)
            add_field("voting_account", Tm_protocol_id_type("account"))
            add_field("num_witness", T_uint16)
            add_field("num_committee", T_uint16)
            add_field("votes", Tm_set(T_vote_id))
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_account_create : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("registrar", Tm_protocol_id_type("account"))
            add_field("referrer", Tm_protocol_id_type("account"))
            add_field("referrer_percent", T_uint16)
            add_field("name", T_string)
            add_field("owner", T_authority)
            add_field("active", T_authority)
            add_field("options", T_account_options)
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_account_update : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("account", Tm_protocol_id_type("account"))
            add_field("owner", Tm_optional(T_authority))
            add_field("active", Tm_optional(T_authority))
            add_field("new_options", Tm_optional(T_account_options))
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_account_upgrade : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("account_to_upgrade", Tm_protocol_id_type("account"))
            add_field("upgrade_to_lifetime_member", T_bool)
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_vesting_balance_withdraw : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("vesting_balance", Tm_protocol_id_type("vesting_balance"))
            add_field("owner", Tm_protocol_id_type("account"))
            add_field("amount", T_asset)
        }
    }
}

class T_op_wrapper : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("op", T_operation)
        }
    }
}

class T_proposal_create : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("fee_paying_account", Tm_protocol_id_type("account"))
            add_field("expiration_time", T_time_point_sec)
            add_field("proposed_ops", Tm_array(T_op_wrapper))
            add_field("review_period_seconds", Tm_optional(T_uint32))
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_proposal_update : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("fee_paying_account", Tm_protocol_id_type("account"))
            add_field("proposal", Tm_protocol_id_type("proposal"))
            add_field("active_approvals_to_add", Tm_set(Tm_protocol_id_type("account")))
            add_field("active_approvals_to_remove", Tm_set(Tm_protocol_id_type("account")))
            add_field("owner_approvals_to_add", Tm_set(Tm_protocol_id_type("account")))
            add_field("owner_approvals_to_remove", Tm_set(Tm_protocol_id_type("account")))
            add_field("key_approvals_to_add", Tm_set(T_public_key))
            add_field("key_approvals_to_remove", Tm_set(T_public_key))
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_proposal_delete : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("fee_paying_account", Tm_protocol_id_type("account"))
            add_field("using_owner_authority", T_bool)
            add_field("proposal", Tm_protocol_id_type("proposal"))
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_asset_update_issuer : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("issuer", Tm_protocol_id_type("account"))
            add_field("asset_to_update", Tm_protocol_id_type("asset"))
            add_field("new_issuer", Tm_protocol_id_type("account"))
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_htlc_create : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("from", Tm_protocol_id_type("account"))
            add_field("to", Tm_protocol_id_type("account"))
            add_field("amount", T_asset)
            add_field("preimage_hash", Tm_static_variant(JSONArray().apply {
                put(Tm_bytes(20))
                put(Tm_bytes(20))
                put(Tm_bytes(32))
            }))
            add_field("preimage_size", T_uint16)
            add_field("claim_period_seconds", T_uint32)
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_htlc_redeem : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("htlc_id", Tm_protocol_id_type("htlc"))
            add_field("redeemer", Tm_protocol_id_type("account"))
            add_field("preimage", Tm_bytes())
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_htlc_extend : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("fee", T_asset)
            add_field("htlc_id", Tm_protocol_id_type("htlc"))
            add_field("update_issuer", Tm_protocol_id_type("account"))
            add_field("seconds_to_add", T_uint32)
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_operation : T_Base() {
    companion object : T_Base_companion() {
        override fun to_byte_buffer(io: BinSerializer, opdata: Any?) {
            assert(opdata is JSONArray)
            val ary = opdata as JSONArray
            assert(ary.length() == 2)

            val opcode = ary.getInt(0)
            val optype = _get_optype_from_opcode(opcode)

            //  1、write opcode    2、write opdata
            io.write_varint32(opcode)
            encode_to_bytes_with_type(optype, ary.get(1), io)
        }

        override fun to_object(opdata: Any?): Any? {
            assert(opdata is JSONArray)
            val ary = opdata as JSONArray
            assert(ary.length() == 2)

            val opcode = ary.getInt(0)
            val optype = _get_optype_from_opcode(opcode)

            val value = encode_to_object_with_type(optype, ary.get(1))
            assert(value != null)
            return jsonArrayfrom(opcode, value!!)
        }

        private fun _get_optype_from_opcode(opcode: Int): T_Base_companion {
            //  TODO:add new op here...
            return when (opcode) {
                EBitsharesOperations.ebo_transfer.value -> T_transfer
                EBitsharesOperations.ebo_limit_order_create.value -> T_limit_order_create
                EBitsharesOperations.ebo_limit_order_cancel.value -> T_limit_order_cancel
                EBitsharesOperations.ebo_call_order_update.value -> T_call_order_update
                EBitsharesOperations.ebo_account_create.value -> T_account_create
                EBitsharesOperations.ebo_account_update.value -> T_account_update
                EBitsharesOperations.ebo_account_upgrade.value -> T_account_upgrade
                EBitsharesOperations.ebo_vesting_balance_withdraw.value -> T_vesting_balance_withdraw
                EBitsharesOperations.ebo_proposal_create.value -> T_proposal_create
                EBitsharesOperations.ebo_proposal_update.value -> T_proposal_update
                EBitsharesOperations.ebo_proposal_delete.value -> T_proposal_delete
                EBitsharesOperations.ebo_asset_update_issuer.value -> T_asset_update_issuer
                EBitsharesOperations.ebo_htlc_create.value -> T_htlc_create
                EBitsharesOperations.ebo_htlc_redeem.value -> T_htlc_redeem
                EBitsharesOperations.ebo_htlc_extend.value -> T_htlc_extend
                else -> {
                    assert(false)
                    return T_transfer
                }
            }
        }
    }
}

class T_transaction : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("ref_block_num", T_uint16)
            add_field("ref_block_prefix", T_uint32)
            add_field("expiration", T_time_point_sec)
            add_field("operations", Tm_array(T_operation))
            add_field("extensions", Tm_set(T_future_extensions))
        }
    }
}

class T_signed_transaction : T_Base() {
    companion object : T_Base_companion() {
        override fun register_subfields() {
            add_field("ref_block_num", T_uint16)
            add_field("ref_block_prefix", T_uint32)
            add_field("expiration", T_time_point_sec)
            add_field("operations", Tm_array(T_operation))
            add_field("extensions", Tm_set(T_future_extensions))
            //  仅比 T_transaction 对象多了 65 字节签名。
            add_field("signatures", Tm_array(Tm_bytes(65)))
        }
    }
}