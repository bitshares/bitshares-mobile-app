package bitshares

import com.btsplusplus.fowallet.NativeInterface
import java.io.ByteArrayOutputStream
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.experimental.xor

class HDWallet {

    //  单例方法
    companion object {

        fun fromMnemonic(mnemonic: String): HDWallet {
            return fromMasterSeed(mnemonicToMasterSeed(mnemonic)!!)
        }

        fun fromMasterSeed(seed: ByteArray): HDWallet {
            return HDWallet().initWithMasterSeed(seed)
        }

        /**
         * (public) 【BIP39】根据助记词生成种子。
         * 参考：https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
         */
        fun mnemonicToMasterSeed(mnemonic: String, passphrase: String? = null): ByteArray? {
            //  为了从助记词中生成二进制种子，BIP39 采用 PBKDF2 函数推算种子，其参数如下：
            //  【助记词句子作为密码，"mnemonic" + passphrase 作为盐，2048 作为重复计算的次数，HMAC-SHA512 作为随机算法，512 位(64 字节)是期望得到的密钥长度】
            return pbkdf2_hmac_sha512(mnemonic.utf8String(), _salt(passphrase).utf8String(), 2048, 64)
        }

        private fun pbkdf2_hmac_sha512(password: ByteArray, salt: ByteArray, iterations: Int, keylen: Int): ByteArray {
            val dk = ByteArrayOutputStream()

            val tm = ByteArrayOutputStream()
            tm.write(salt)
            tm.write(byteArrayOf(0, 0, 0, 0))
            val block1 = tm.toByteArray()
            val salt_size = salt.size

            //  REMARK: hmacSHA512 byte size
            val hLen = 64
            val count = Math.ceil(keylen / hLen.toDouble()).toInt()

            for (i in 1..count) {
                //  REMARK：index is BigEndian
                block1[salt_size + 3] = (i and 0xFF).toByte()
                block1[salt_size + 2] = (i.ushr(8) and 0xFF).toByte()
                block1[salt_size + 1] = (i.ushr(16) and 0xFF).toByte()
                block1[salt_size + 0] = (i.ushr(24) and 0xFF).toByte()

                val T = hmacSHA512(block1, password)!!
                var U = T

                for (j in 1 until iterations) {
                    U = hmacSHA512(U, password)!!
                    for (k in 0 until hLen) {
                        T[k] = T[k].xor(U[k])
                    }
                }

                dk.write(T)
            }

            return dk.toByteArray()
        }

        fun hmacSHA512(data: ByteArray, key: ByteArray): ByteArray? {
            try {
                val secretKey = SecretKeySpec(key, "HmacSHA512")
                val mac = Mac.getInstance("HmacSHA512")
                mac.init(secretKey)
                return mac.doFinal(data)
            } catch (e: Exception) {
                return null
            }
        }

        private fun _salt(passphrase: String?): String {
            return "mnemonic${passphrase ?: ""}"
        }
    }

    var privateKey: ByteArray? = null
    var chainCode: ByteArray? = null
    var index: Long = 0
    var depth: Int = 0

    fun initWithMasterSeed(seed: ByteArray): HDWallet {
        //  https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
        val result = HDWallet.hmacSHA512(seed, "Bitcoin seed".utf8String())!!
        this.privateKey = result.sliceArray(IntRange(0, 31))
        this.chainCode = result.sliceArray(IntRange(32, 63))
        this.index = 0
        this.depth = 0
        return this
    }

    /**
     *  (public) 获取 WIF 格式私钥。
     */
    fun toWifPrivateKey(): String {
        return OrgUtils.genBtsWifPrivateKeyByPrivateKey32(this.privateKey!!)
    }

    /**
     *  (public) 获取 WIF 格式公钥。
     */
    fun toWifPublicKey(): String? {
        return OrgUtils.genBtsAddressFromWifPrivateKey(toWifPrivateKey())
    }

    fun deriveBitshares(type: EHDBitsharesPermissionType): HDWallet {
        return when (type) {
            EHDBitsharesPermissionType.ehdbpt_owner -> derive("m/48'/1'/0'/0'/0'")
            EHDBitsharesPermissionType.ehdbpt_active -> derive("m/48'/1'/1'/0'/0'")
            EHDBitsharesPermissionType.ehdbpt_memo -> derive("m/48'/1'/3'/0'/0'")
        }
    }

    fun derive(path: String): HDWallet {
        //  参考：https://github.com/cryptocoinjs/hdkey/blob/master/lib/hdkey.js

        //  REMARK: hardened const
        val HARDENED_OFFSET = 0x80000000

        var curr_hd = this

        val entries = path.split("/")

        entries.forEachIndexed { idx, src ->
            if (idx == 0) {
                assert(src == "m" || src == "M")
            } else {
                val hardened = src.isNotEmpty() && src.substring(src.length - 1) == "'"
                var childIndex = (if (hardened) src.substring(0, src.length - 1) else src).toLong()
                assert(childIndex <= HARDENED_OFFSET)
                if (hardened) {
                    childIndex += HARDENED_OFFSET
                    curr_hd = deriveChildHardened(childIndex, curr_hd)
                } else {
                    TODO("暂不支持non-hardened")
                    curr_hd = deriveChildNonHardened(childIndex, curr_hd)
                }
            }
        }

        return curr_hd
    }

    private fun deriveChildHardened(childIndex: Long, curr_hd: HDWallet): HDWallet {
        //  HMAC-SHA512(Key = cpar, Data = 0x00 || ser256(kpar) || ser32(i))
        val data = ByteArrayOutputStream()
        data.write(byteArrayOf(0))
        data.write(curr_hd.privateKey)

        //  REMARK：index is BigEndian
        data.write((childIndex.ushr(24) and 0xFF).toInt())
        data.write((childIndex.ushr(16) and 0xFF).toInt())
        data.write((childIndex.ushr(8) and 0xFF).toInt())
        data.write((childIndex and 0xFF).toInt())

        val result = HDWallet.hmacSHA512(data.toByteArray(), curr_hd.chainCode!!)!!

        val il = result.sliceArray(IntRange(0, 31))
        val ir = result.sliceArray(IntRange(32, 63))

        //  子私钥
        val tweaked_private_key = NativeInterface.sharedNativeInterface().bts_privkey_tweak_add(curr_hd.privateKey!!, il)
        if (tweaked_private_key == null) {
            return deriveChildHardened(childIndex + 1, curr_hd)
        }

        //  返回
        val new_hd = HDWallet()
        new_hd.privateKey = tweaked_private_key
        new_hd.chainCode = ir
        new_hd.index = childIndex
        new_hd.depth = curr_hd.depth + 1
        return new_hd
    }

    private fun deriveChildNonHardened(childIndex: Long, curr_hd: HDWallet): HDWallet {
        TODO("暂不支持")
        return this
    }
}


