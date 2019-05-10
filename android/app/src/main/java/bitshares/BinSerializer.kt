package bitshares

import VarInt.VarInt
import com.btsplusplus.fowallet.NativeInterface
import com.fowallet.walletcore.bts.ChainObjectManager
import com.macfaq.io.LittleEndianOutputStream
import java.io.ByteArrayOutputStream

class BinSerializer {

    var _data: ByteArrayOutputStream = ByteArrayOutputStream()
    var _io: LittleEndianOutputStream = LittleEndianOutputStream(_data)

    fun get_data(): ByteArray {
        return _data.toByteArray()
    }

    fun write_u8(value: Int): BinSerializer {
        _io.writeByte(value)
        return this
    }

    fun write_u16(value: Int): BinSerializer {
        _io.writeShort(value)
        return this
    }

    fun write_u32(value: Long): BinSerializer {
        _io.writeInt(value.toInt())
        return this
    }

    fun write_u64(value: Long): BinSerializer {
        //  TODO:Long < u64
        _io.writeLong(value)
        return this
    }

    fun write_s64(value: Long): BinSerializer {
        _io.writeLong(value)
        return this
    }

    fun write_varint32(value: Int): BinSerializer {
        val varint_tmpbuf = ByteArray(10)
        val offset = VarInt.putVarInt(value, varint_tmpbuf, 0)
        _io.write(varint_tmpbuf, 0, offset)
        return this
    }

    /**
     * 写入对象ID类型（格式：x.x.x）
     */
    fun write_object_id(value: String): BinSerializer {
        //  TODO:格式验证 x.x.xxx
        val ary = value.split(".")
        val oid = ary[ary.size - 1]
        this.write_varint32(oid.toInt())
        return this
    }

    /**
     * 写入公钥对象。REMARK：BTS开头的地址。
     */
    fun write_public_key(public_key_address: String): BinSerializer {
        val public_key = NativeInterface.sharedNativeInterface().bts_gen_public_key_from_b58address(public_key_address.utf8String(), ChainObjectManager.sharedChainObjectManager().grapheneAddressPrefix.utf8String())
        if (public_key == null) {
            //  无效公钥地址，不写入。
            return this
        }
        val output33 = NativeInterface.sharedNativeInterface().bts_gen_public_key_compressed(public_key)
        //  写入33字节压缩公钥
        _io.write(output33)
        return this
    }

    /**
     * 写入字符串（变长，包含长度信息）
     */
    fun write_string(value: String): BinSerializer {
        val len = value.length
        this.write_varint32(len)
        if (len > 0) {
            _io.write(value.utf8String())
        }
        return this
    }

    /**
     * 写入字符串（定长，不包含长度信息）
     */
    fun write_fix_string(value: String): BinSerializer {
        _io.write(value.utf8String())
        return this
    }

    /**
     * 写入2进制流
     */
    fun write_bytes(value: ByteArray, with_size: Boolean): BinSerializer {
        if (with_size) {
            this.write_varint32(value.size)
        }
        _io.write(value)
        return this
    }
}