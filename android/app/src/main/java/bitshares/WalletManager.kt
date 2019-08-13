package com.fowallet.walletcore.bts

import android.content.Context
import bitshares.*
import com.btsplusplus.fowallet.NativeInterface
import com.btsplusplus.fowallet.R
import org.json.JSONArray
import org.json.JSONObject


class WalletManager {
    //  单例方法
    companion object {
        private var _sharedWalletManager: WalletManager? = null
        fun sharedWalletManager(): WalletManager {
            if (_sharedWalletManager == null) {
                _sharedWalletManager = WalletManager()
            }
            return _sharedWalletManager!!
        }

        /**
         * (public) 辅助生成 nonce uint64 数字
         */
        fun genUniqueNonceUint64(): String {
            val entropy = _genUniqueNonceEntropy()
            val now_sec = Utils.now_ts()
            var value = (now_sec * 1000).toLong()
            //  TODO:uint64 考虑越界问题
            value = value.shl(8) or (entropy.toLong() and 0xFF)
            return value.toString()
        }

        private var _unique_nonce_entropy: Int = -1  //  辅助生成 unique64 用的熵
        private fun _genUniqueNonceEntropy(): Int {
            if (_unique_nonce_entropy < 0) {
                val data = secureRandomByte32()
                _unique_nonce_entropy = data[0].toUnsignedInt()
            } else {
                _unique_nonce_entropy = (_unique_nonce_entropy + 1) % 256
            }
            return _unique_nonce_entropy
        }

        /**
         * (public) 创建安全的随机字节(16进制返回，结果为64字节。)
         */
        fun secureRandomByte32Hex(): String {
            return secureRandomByte32().hexEncode()
        }

        /**
         * (public) 创建安全的随机字节
         */
        fun secureRandomByte32(): ByteArray {
            //  系统语言
            val lang = java.util.Locale.getDefault().language.toString()
            //  系统版本
            val sysver = android.os.Build.VERSION.RELEASE.toString()
            //  手机型号
            val model = android.os.Build.MODEL.toString()
            //  手机厂商
            val brand = android.os.Build.BRAND.toString()

            //  第一次构造 entropy
            val pUniqueString = "time:${java.util.Date().time}|random:${Math.random()}"
            var entropy = "${lang}|${sysver}|${model}|${brand}|${pUniqueString}"
            val digest = sha256hex(entropy.utf8String())

            //  第二次构造 entropy
            entropy = "android:d1:${digest}|date:${java.util.Date().time}|rand:${Math.random()}"
            return sha256(entropy.utf8String())
        }

        /**
         * (public) 随机生成私钥
         */
        fun randomPrivateKeyWIF(): String {
            return OrgUtils.genBtsWifPrivateKey(secureRandomByte32())
        }

        /**
         * (public) 【静态方法】判断给定私钥列表对于指定权限的状态（足够、部分、完整、无权限）。（active权限、owner权限）
         */
        fun calcPermissionStatus(raw_permission_json: JSONObject, privateKeysHash: JSONObject): EAccountPermissionStatus {
            val weight_threshold = raw_permission_json.getString("weight_threshold").toInt()
            assert(weight_threshold > 0)
            var curr_weights = 0
            var miss_partial_key = false
            val key_auths = raw_permission_json.optJSONArray("key_auths")
            if (key_auths != null && key_auths.length() > 0) {
                key_auths.forEach<JSONArray> {
                    val pair = it!!
                    assert(pair.length() == 2)
                    val pubkey = pair.getString(0)
                    val weight = pair.getString(1).toInt()
                    if (privateKeysHash.has(pubkey)) {
                        curr_weights += weight
                    } else {
                        miss_partial_key = true
                    }
                }
            }
            if (curr_weights >= weight_threshold) {
                if (miss_partial_key) {
                    //  足够权限：可以签署交易。
                    return EAccountPermissionStatus.EAPS_ENOUGH_PERMISSION
                } else {
                    //  所有权限：可以签署交易。
                    return EAccountPermissionStatus.EAPS_FULL_PERMISSION
                }
            } else if (curr_weights > 0) {
                //  部分权限：不可单独签署交易。
                return EAccountPermissionStatus.EAPS_PARTIAL_PERMISSION
            } else {
                //  无权限：不可签署交易。
                return EAccountPermissionStatus.EAPS_NO_PERMISSION
            }
        }

        /**
         * (public)【静态方法】判断给定的密钥列表是否足够授权指定权限（active权限、owner权限）
         */
        fun canAuthorizeThePermission(raw_permission_json: JSONObject, privateKeysHash: JSONObject): Boolean {
            val status = calcPermissionStatus(raw_permission_json, privateKeysHash)
            return (status == EAccountPermissionStatus.EAPS_FULL_PERMISSION || status == EAccountPermissionStatus.EAPS_ENOUGH_PERMISSION)
        }

        /**
         *  (public) 判断指定权限是否需要多签。
         */
        fun isMultiSignPermission(raw_permission_json: JSONObject): Boolean {
            //  账号参与多签
            val account_auths = raw_permission_json.optJSONArray("account_auths")
            if (account_auths != null && account_auths.length() > 0) {
                return true
            }

            //  地址多签（几乎没用到）
            val address_auths = raw_permission_json.optJSONArray("address_auths")
            if (address_auths != null && address_auths.length() > 0) {
                return true
            }

            //  私钥参与多签
            val key_auths = raw_permission_json.optJSONArray("key_auths")
            if (key_auths != null && key_auths.length() >= 2) {
                return true
            }

            //  普通权限：无多签
            return false
        }

        /**
         *  (public) 判断指定账号否需要多签。
         */
        fun isMultiSignAccount(account_data: JSONObject): Boolean {
            //  Active 权限多签
            val active = account_data.getJSONObject("active")
            if (isMultiSignPermission(active)) {
                return true
            }

            //  Owner 权限多签
            val owner = account_data.getJSONObject("owner")
            if (isMultiSignPermission(owner)) {
                return true
            }

            //  普通账号：无多签
            return false
        }


        /**
         *  (public) 提取账号数据中所有公钥数据。
         */
        fun getAllPublicKeyFromAccountData(account_data: JSONObject, result: JSONObject? = null): JSONObject {
            val res = result ?: JSONObject()

            val active = account_data.getJSONObject("active")
            val owner = account_data.getJSONObject("owner")
            val active_key_auths = active.getJSONArray("key_auths")
            val owner_key_auths = owner.getJSONArray("key_auths")

            active_key_auths.forEach<JSONArray> {
                val item = it!!
                assert(item.length() == 2)
                res.put(item.getString(0), true)
            }

            owner_key_auths.forEach<JSONArray> {
                val item = it!!
                assert(item.length() == 2)
                res.put(item.getString(0), true)
            }

            val options = account_data.getJSONObject("options")
            res.put(options.getString("memo_key"), true)

            return res
        }

        /**
         * (public) 归一化脑密钥，按照不可见字符切分字符串，然后用标准空格连接。
         */
        fun normalizeBrainKey(brainKey: String): String {
            //  方便匹配正则，末尾添加一个空格作为不可见自负。
            val str = "${brainKey} "
            val reg = Regex("(\\S+)([\\s]+)", RegexOption.IGNORE_CASE)
            val list = reg.findAll(str).map {
                return@map it.value.trim()
            }
            return list.joinToString(" ")
        }

        /**
         * (public) 根据脑密钥单词字符串生成对应的WIF格式私钥（脑密钥字符串作为seed）。
         */
        fun genBrainKeyPrivateWIF(brainKeyPlainText: String): String {
            return OrgUtils.genBtsWifPrivateKey(normalizeBrainKey(brainKeyPlainText).utf8String())
        }

        /**
         * (public) 根据脑密钥单词字符串 和 HD子密钥索引编号 生成WIF格式私钥。REMARK：sha512(brainKey + " " + seq)作为seed。
         */
        fun genPrivateKeyFromBrainKey(brainKeyPlainText: String, sequence: Int): String {
            assert(sequence >= 0)
            val str = "${normalizeBrainKey(brainKeyPlainText)} ${sequence}"
            val digest64 = sha512(str.utf8String())
            return OrgUtils.genBtsWifPrivateKey(digest64)
        }

    }

    //  脑密钥字典
    private var _brainkey_dictionary: List<String>? = null

    //  [仅钱包模式存在] 钱包文件解密后的json
    private var _wallet_object_json: JSONObject? = null

    //  [仅钱包模式存在] 钱包密码
    private var _wallet_password: String? = null

    //  [钱包+账号模式都存在] 内存中存在的所有私有信息    Key：PublicKey   Value：WIFPrivateKey
    private var _private_keys_hash = JSONObject()

    /**
     * (public) 判断指定帐号是否是登录帐号自身。自己的帐号返回 YES，他人的帐号返回 NO。
     */
    fun isMyselfAccount(account_name: String?): Boolean {
        if (account_name == null) {
            return false
        }
        //  尚未登录，钱包不存在，返回NO。
        if (!isWalletExist()) {
            return false
        }
        //  帐号名字和钱包中存储的帐号名一致，则是自己的帐号。
        if (getWalletAccountName()!! == account_name) {
            return true
        }
        return false
    }

    fun isWalletExist(): Boolean {
        return getWalletMode() != AppCacheManager.EWalletMode.kwmNoWallet.value
    }

    /**
     * (public) 是否缺少完整的帐号信息，在注册的时候低概率注册成功，但获取帐号信息失败了。
     */
    fun isMissFullAccountData(): Boolean {
        val account = getWalletAccountInfo()
        if (account == null) {
            return true
        }
        return false
    }

    /**
     * (public) 获取本地钱包信息
     */
    fun getWalletInfo(): JSONObject {
        return AppCacheManager.sharedAppCacheManager().getWalletInfo()
    }

    fun getWalletMode(): Int {
        return getWalletInfo().optInt("kWalletMode")
    }

    /**
     * (public) 导入的帐号是否是密码模式导入的
     */
    fun isPasswordMode(): Boolean {
        return getWalletMode() == AppCacheManager.EWalletMode.kwmPasswordOnlyMode.value
    }

    fun getWalletAccountInfo(): JSONObject? {
        return getWalletInfo().optJSONObject("kAccountInfo")
    }

    fun getWalletAccountName(): String? {
        return getWalletInfo().optString("kAccountName")
    }

    /**
     * (public) 锁定和解锁帐号
     */
    fun isLocked(): Boolean {
        //  无钱包
        if (!isWalletExist()) {
            return true
        }
        //  存在钱包信息，则说明已经解锁。（钱包模式）
        if (_wallet_object_json != null) {
            return false
        }
        //  内存中有私钥信息，则说明已解锁。（账号模式）
        if (_private_keys_hash.length() > 0) {
            return false
        }
        //  锁定中
        return true
    }

    fun Lock() {
        _wallet_object_json = null
        _wallet_password = null
        _private_keys_hash = JSONObject()
    }

    /**
     * (public) 解锁帐号，返回 {@"unlockSuccess":@"解锁是否成功", @"err":@"错误信息", "haveActivePermission":@"是否有足够的资金权限"}。
     */
    fun unLock(password: String, ctx: Context): JSONObject {
        //  先锁定
        Lock()
        //  继续解锁
        val mode = getWalletMode()
        return when (mode) {
            AppCacheManager.EWalletMode.kwmPasswordOnlyMode.value -> _unLockPasswordMode(password, ctx)
            else -> _unLockFullWallet(password, ctx)
        }
    }

    /**
     * (public) 刷新解锁信息（仅针对钱包模式）
     */
    fun reUnlock(ctx: Context): JSONObject {
        assert(_wallet_password != null)
        return unLock(_wallet_password!!, ctx)
    }

    /**
     * (private) 解锁：密码模式
     */
    private fun _unLockPasswordMode(password: String, ctx: Context): JSONObject {
        assert(isPasswordMode())
        val full_data = getWalletAccountInfo()
        if (full_data == null) {
            return jsonObjectfromKVS("unlockSuccess", false, "haveActivePermission", false, "err", "no account data")
        }
        val account = full_data.getJSONObject("account")
        val account_name = account.getString("name")

        //  通过账号密码计算active和owner私钥信息。
        val active_seed = "${account_name}active${password}"
        val active_private_wif = OrgUtils.genBtsWifPrivateKey(active_seed.utf8String())
        val owner_seed = "${account_name}owner${password}"
        val owner_private_wif = OrgUtils.genBtsWifPrivateKey(owner_seed.utf8String())
        val active_pubkey = OrgUtils.genBtsAddressFromWifPrivateKey(active_private_wif)!!
        val owner_pubkey = OrgUtils.genBtsAddressFromWifPrivateKey(owner_private_wif)!!

        //  保存到内存
        _private_keys_hash = JSONObject()
        _private_keys_hash.put(active_pubkey, active_private_wif)
        _private_keys_hash.put(owner_pubkey, owner_private_wif)

        if (canAuthorizeThePermission(account.getJSONObject("active"))) {
            //  解锁成功 & 有权限OK
            return jsonObjectfromKVS("unlockSuccess", true, "haveActivePermission", true, "err", "ok")
        } else {
            //  解锁失败 & 权限不足：私钥不正确（即密码不正确。）
            _private_keys_hash = JSONObject()
            return jsonObjectfromKVS("unlockSuccess", false, "haveActivePermission", false, "err", R.string.kLoginSubmitTipsAccountPasswordIncorrect.xmlstring(ctx))
        }
    }

    /**
     * (private) 解锁：完整钱包模式
     */
    private fun _unLockFullWallet(wallet_password: String, ctx: Context): JSONObject {
        val wallet_info = getWalletInfo()
        val hex_wallet_bin = wallet_info.optString("kFullWalletBin", "")
        if (hex_wallet_bin == "") {
            return jsonObjectfromKVS("unlockSuccess", false, "err", R.string.kWalletInvalidWalletPassword.xmlstring(ctx))
        }
        _wallet_object_json = loadFullWalletFromHex(hex_wallet_bin, wallet_password)
        if (_wallet_object_json == null) {
            return jsonObjectfromKVS("unlockSuccess", false, "err", R.string.kWalletIncorrectWalletPassword.xmlstring(ctx))
        }
        val private_keys = _wallet_object_json!!.getJSONArray("private_keys")
        val wallet = _wallet_object_json!!.getJSONArray("wallet")[0] as JSONObject

        //  1、用钱包的 encryption_key 解密后的值作为密钥解密 active encrypted_key 私钥
        _wallet_password = wallet_password
        val data_encryption_buffer = auxAesDecryptFromHex(wallet_password.utf8String(), wallet.getString("encryption_key").utf8String())

        //  2、解密钱包中存在的所有私钥。
        _private_keys_hash = JSONObject()
        private_keys.forEach<JSONObject> {
            val key_item = it!!
            val pubkey = key_item.getString("pubkey")
            val data_private_key32 = auxAesDecryptFromHex(data_encryption_buffer!!, key_item.getString("encrypted_key").utf8String())
            val private_key_wif = OrgUtils.genBtsWifPrivateKeyByPrivateKey32(data_private_key32!!)
            _private_keys_hash.put(pubkey, private_key_wif)
        }

        //  3、判断权限
        val full_data = getWalletAccountInfo()
        if (full_data == null) {
            return jsonObjectfromKVS("unlockSuccess", true, "haveActivePermission", false, "err", R.string.kWalletNoAccountData.xmlstring(ctx))
        }
        val account = full_data.getJSONObject("account")
        if (canAuthorizeThePermission(account.getJSONObject("active"))) {
            return jsonObjectfromKVS("unlockSuccess", true, "haveActivePermission", true, "err", "ok")
        } else {
            return jsonObjectfromKVS("unlockSuccess", true, "haveActivePermission", false, "err", R.string.kWalletPermissionNoEnough.xmlstring(ctx))
        }
    }

    /**
     * (public) 获取所有账号，并以“name”或者“id“作为KEY构造Hash返回。
     */
    fun getAllAccountDataHash(hashKeyIsName: Boolean): JSONObject {
        val result = JSONObject()
        val hashKey = if (hashKeyIsName) "name" else "id"

        val localWalletInfo = getWalletInfo()

        val accountDataList = localWalletInfo.optJSONArray("kAccountDataList")
        if (accountDataList != null && accountDataList.length() > 0) {
            accountDataList.forEach<JSONObject> {
                val accountData = it!!
                val keyValue = accountData.getString(hashKey)
                result.put(keyValue, accountData)
            }
        }

        val currentFullAccountData = localWalletInfo.optJSONObject("kAccountInfo")
        if (currentFullAccountData != null) {
            val accountData = currentFullAccountData.getJSONObject("account")
            val keyValue = accountData.getString(hashKey)
            result.put(keyValue, accountData)
        }

        return result
    }

    /**
     * 获取钱包中所有账号列表。（仅有一个主账号。）
     * 钱包已解锁则从BIN文件账号列表字段获取，未解锁则从Cache获取。
     */
    fun getWalletAccountNameList(): JSONArray {
        if (isLocked() || isPasswordMode()) {
            val result = getAllAccountDataHash(true)
            assert(result.length() > 0)
            return result.keys().toJSONArray()
        } else {
            assert(_wallet_object_json != null)
            val linked_accounts = _wallet_object_json!!.getJSONArray("linked_accounts")
            assert(linked_accounts.length() > 0)
            val chain_id = ChainObjectManager.sharedChainObjectManager().grapheneChainID
            val result = JSONArray()
            linked_accounts.forEach<JSONObject> {
                val account_item = it!!
                if (account_item.getString("chainId") == chain_id) {
                    result.put(account_item.getString("name"))
                }
            }
            return result
        }
    }

    /**
     * (public) 获取当前钱包中有完整"指定"权限的所有账号列表。REMARK：如果列表为空(所有账号都没权限)，则全部返回。
     */
    fun getFeePayingAccountList(requireActivePermission: Boolean): JSONArray {
        //  获取所有账号
        val allAccountDataList = getAllAccountDataHash(true).values()
        assert(!isLocked())

        //  判断本地钱包包含哪些账号的Active权限
        val permissionKey = if (requireActivePermission) "active" else "owner"
        val haveActivePermissionAccountList = JSONArray()
        allAccountDataList.forEach<JSONObject> {
            val account_info = it!!
            val permissionItem = account_info.getJSONObject(permissionKey)
            if (canAuthorizeThePermission(permissionItem)) {
                haveActivePermissionAccountList.put(account_info)
            }
        }
        //  REMARK：有满足权限的账号则仅返回满足权限的列表，否则全部返回。
        if (haveActivePermissionAccountList.length() > 0) {
            return haveActivePermissionAccountList
        } else {
            return allAccountDataList
        }
    }

    /**
     * (public) 是否存在指定公钥的私钥对象。
     */
    fun havePrivateKey(pubkey: String): Boolean {
        assert(!isLocked())
        return _private_keys_hash.has(pubkey)
    }

    /**
     * (public) 获取本地钱包中需要参与【指定权限、active或owner等】签名的必须的 公钥列表。
     */
    fun getSignKeys(raw_permission_json: JSONObject): JSONArray {
        assert(!isLocked())
        val result = JSONArray()

        val weight_threshold = raw_permission_json.getString("weight_threshold").toInt()
        assert(weight_threshold > 0)

        var curr_weights = 0

        val key_auths = raw_permission_json.optJSONArray("key_auths")
        if (key_auths != null && key_auths.length() > 0) {
            for (pair in key_auths.forin<JSONArray>()) {
                assert(pair!!.length() == 2)
                val pubkey = pair.getString(0)
                val weight = pair.getString(1).toInt()
                if (havePrivateKey(pubkey)) {
                    result.put(pubkey)
                    curr_weights += weight
                    if (curr_weights >= weight_threshold) {
                        break
                    }
                }
            }
        }

        //  确保权限足够（返回的KEY签名之后的阈值之后达到触发阈值）
        assert(canAuthorizeThePermission(raw_permission_json))
        return result
    }

    /**
     * (public) 根据手续费支付账号ID获取本地钱包中需要参与签名的 公钥列表。REMARK：手续费支付账号应该在本地钱包中存在。
     */
    fun getSignKeysFromFeePayingAccount(fee_paying_account: String, requireOwnerPermission: Boolean = false): JSONArray {
        val permissionKey = if (requireOwnerPermission) "owner" else "active"

        val localWalletInfo = getWalletInfo()

        val accountDataList = localWalletInfo.optJSONArray("kAccountDataList")
        if (accountDataList != null && accountDataList.length() > 0) {
            accountDataList.forEach<JSONObject> {
                val accountData = it!!
                if (accountData.getString("id") == fee_paying_account) {
                    return getSignKeys(accountData.getJSONObject(permissionKey))
                }
            }
        }

        //  没有 kAccountDataList 字段则获取当前完整账号信息。（账号模式可能不存在 kAccountDataList 字段。）
        val currentFullAccountData = localWalletInfo.optJSONObject("kAccountInfo")
        if (currentFullAccountData != null) {
            val accountData = currentFullAccountData.optJSONObject("account")
            if (accountData != null && accountData.getString("id") == fee_paying_account) {
                return getSignKeys(accountData.getJSONObject(permissionKey))
            }
        }

        //  not reached...
        assert(false)
        return JSONArray()
    }

    /**
     * (public) 是否有足够的权限状态判断。（本地钱包中的私钥是否足够签署交易，否则视为提案交易。）
     */
    fun calcPermissionStatus(raw_permission_json: JSONObject): EAccountPermissionStatus {
        assert(!isLocked())
        return WalletManager.calcPermissionStatus(raw_permission_json, _private_keys_hash)
    }

    /**
     * (public) 本地钱包的密钥是否足够授权指定权限（active权限、owner权限）
     */
    fun canAuthorizeThePermission(raw_permission_json: JSONObject): Boolean {
        assert(!isLocked())
        return WalletManager.canAuthorizeThePermission(raw_permission_json, _private_keys_hash)
    }

    /**
     *  (public) 用一组私钥签名交易。成功返回签名数据的数组，失败返回 nil。
     */
    fun signTransaction(sign_buffer: ByteArray, signKeys: JSONArray): JSONArray? {
        assert(signKeys.length() > 0)
        //  未解锁 返回失败
        if (isLocked()) {
            return null
        }

        //  循环签名
        val result = JSONArray()
        for (pubkey in signKeys.forin<String>()) {
            //  获取WIF私钥
            val private_key_wif = _private_keys_hash.getString(pubkey!!)

            //  生成KEY32私钥
            val private_key32 = NativeInterface.sharedNativeInterface().bts_gen_private_key_from_wif_privatekey(private_key_wif.utf8String())
            if (private_key32 == null) {
                return null
            }

            //  签名
            val signature65 = NativeInterface.sharedNativeInterface().bts_sign_buffer(sign_buffer, private_key32)
            if (signature65 == null) {
                return null
            }
            result.put(signature65)
        }
        return result
    }

    /**
     * (public) 加密并生成 memo 信息结构体，失败返回 nil。
     */
    fun genMemoObject(memo: String, from_public: String, to_public: String): JSONObject? {
        assert(!isLocked())

        //  1、获取和 from_public 对应的备注私钥
        val from_public_private_key_wif = _private_keys_hash.optString(from_public, "")
        if (from_public_private_key_wif == "") {
            return null
        }

        val memo_private_key32 = NativeInterface.sharedNativeInterface().bts_gen_private_key_from_wif_privatekey(from_public_private_key_wif.utf8String())
        if (memo_private_key32 == null) {
            return null
        }

        //  接收方的公钥
        val public_key = NativeInterface.sharedNativeInterface().bts_gen_public_key_from_b58address(to_public.utf8String(), ChainObjectManager.sharedChainObjectManager().grapheneAddressPrefix.utf8String())
        //  公钥无效
        if (public_key == null) {
            return null
        }

        //  3、生成加密用 nonce
        val nonce = WalletManager.genUniqueNonceUint64()

        //  4、加密
        val output = NativeInterface.sharedNativeInterface().bts_aes256_encrypt_with_checksum(memo_private_key32, public_key, nonce.utf8String(), memo.utf8String())
        //  加密失败
        if (output == null) {
            return null
        }

        //  返回  REMARK：加密后的 data 不能 json 序列化的，需要hexencode，否则会crash。
        val item = JSONObject()
        item.put("from", from_public)
        item.put("to", to_public)
        item.put("nonce", nonce)
        item.put("message", output)
        return item
    }

    /**
     * (public) 加载完成钱包文件
     */
    fun loadFullWalletFromHex(hex_wallet_bin: String, wallet_password: String): JSONObject? {
        return loadFullWallet(hex_wallet_bin.hexDecode(), wallet_password)
    }

    fun loadFullWallet(wallet_bin: ByteArray, wallet_password: String): JSONObject? {
        val output_data = NativeInterface.sharedNativeInterface().bts_load_wallet(wallet_bin, wallet_password.utf8String())
        if (output_data == null) {
            return null
        }
        try {
            return JSONObject(output_data.utf8String())
        } catch (err: Exception) {
            return null
        }
    }

    /**
     * (public) 在当前“已解锁”的钱包中移除账号和私钥数据。
     */
    fun walletBinRemoveAccount(account_name: String?, pubkeyList: JSONArray?): ByteArray? {
        assert(!isPasswordMode())
        assert(!isLocked())
        assert(_wallet_object_json != null)

        //  账号和公钥至少存在一个。
        assert(account_name != null || (pubkeyList != null && pubkeyList.length() > 0))

        //  1、构造 linked_accounts
        val old_linked_accounts = _wallet_object_json!!.getJSONArray("linked_accounts")
        assert(old_linked_accounts.length() > 0)

        //  钱包中的账号列表默认为之前的老账号。
        var final_linked_accounts = old_linked_accounts
        if (account_name != null) {
            var new_linked_accounts = JSONArray()
            val chain_id = ChainObjectManager.sharedChainObjectManager().grapheneChainID
            old_linked_accounts.forEach<JSONObject> {
                val account = it!!
                if (account.getString("chainId") != chain_id || account.getString("name") != account_name) {
                    //  保留
                    new_linked_accounts.put(account)
                }
            }
            //  设置钱包中的账号列表
            final_linked_accounts = new_linked_accounts
            //  最后一个账号不可删除。
            assert(final_linked_accounts.length() > 0)
        }

        val old_wallet = _wallet_object_json!!.getJSONArray("wallet").getJSONObject(0)

        //  2、构造 private_keys
        val old_private_keys = _wallet_object_json!!.getJSONArray("private_keys")
        var final_private_keys = old_private_keys
        if (pubkeyList != null && pubkeyList.length() > 0) {
            assert(_wallet_password != null)
            val remove_pubkey_hash = JSONObject()
            pubkeyList.forEach<String> {
                remove_pubkey_hash.put(it!!, true)
            }
            val new_private_keys = JSONArray()
            old_private_keys.forEach<JSONObject> {
                val item = it!!
                val pubkey = item.getString("pubkey")
                if (!remove_pubkey_hash.has(pubkey)) {
                    //  保留
                    new_private_keys.put(item)
                }
            }
            //  设置私钥列表。
            final_private_keys = new_private_keys
        }


        //  3、构造 wallet
        val last_modified = genWalletTimeString(Utils.now_ts())
        val new_wallet = old_wallet
        new_wallet.put("last_modified", last_modified)

        //  4、final object
        val final_object = jsonObjectfromKVS("linked_accounts", final_linked_accounts,
                "private_keys", final_private_keys, "wallet", jsonArrayfrom(new_wallet))

        //  5、创建二进制钱包并返回
        return _genFullWalletData(final_object, _wallet_password!!)
    }

    /**
     *  (public) 在当前“已解锁”的钱包中导入账号or私钥数据。REMARK：如果导入的账号名已经存在则设置为当前账号。
     */
    fun walletBinImportAccount(account_name: String?, privateKeyWifList: JSONArray?): ByteArray? {
        assert(!isPasswordMode())
        assert(!isLocked())
        assert(_wallet_object_json != null)

        //  导入账号和导入私钥至少存在一个
        assert(account_name != null || (privateKeyWifList != null && privateKeyWifList.length() > 0))

        //  1、构造 linked_accounts
        val old_linked_accounts = _wallet_object_json!!.getJSONArray("linked_accounts")
        assert(old_linked_accounts.length() > 0)

        //  钱包中的账号列表默认为之前的老账号。
        var final_linked_accounts = old_linked_accounts
        if (account_name != null) {
            var new_linked_accounts = JSONArray()

            //  导入账号 or 设置当前账号
            val chain_id = ChainObjectManager.sharedChainObjectManager().grapheneChainID
            var exist_account_item: JSONObject? = null
            old_linked_accounts.forEach<JSONObject> {
                val account = it!!
                if (account.getString("chainId") == chain_id && account.getString("name") == account_name) {
                    exist_account_item = account
                } else {
                    new_linked_accounts.put(account)
                }
            }
            if (exist_account_item != null) {
                //  账号已经存在：则调整到首位，设置为当前账号。
                val new_ary = jsonArrayfrom(exist_account_item!!)
                new_ary.putAll(new_linked_accounts)
                new_linked_accounts = new_ary
            } else {
                val new_linked_account = jsonObjectfromKVS("chainId", chain_id, "name", account_name)
                new_linked_accounts.put(new_linked_account)
            }
            //  设置钱包中的账号列表
            final_linked_accounts = new_linked_accounts
        }

        val old_wallet = _wallet_object_json!!.getJSONArray("wallet").getJSONObject(0)

        //  2、构造 private_keys
        val old_private_keys = _wallet_object_json!!.getJSONArray("private_keys")
        var final_private_keys = old_private_keys
        if (privateKeyWifList != null && privateKeyWifList.length() > 0) {
            assert(_wallet_password != null)
            val exist_pubkey_hash = JSONObject()
            val new_private_keys = JSONArray()
            old_private_keys.forEach<JSONObject> {
                val item = it!!
                val pubkey = item.getString("pubkey")
                new_private_keys.put(item)
                exist_pubkey_hash.put(pubkey, true)
            }

            //  1、用钱包的 encryption_key 解密后的值作为密钥解密 active encrypted_key 私钥
            val data_encryption_buffer = auxAesDecryptFromHex(_wallet_password!!.utf8String(), old_wallet.getString("encryption_key").utf8String())!!
            for (private_wif in privateKeyWifList.forin<String>()) {
                val pubkey = OrgUtils.genBtsAddressFromWifPrivateKey(private_wif!!)!!
                //  已存在，不用重复导入。
                if (exist_pubkey_hash.has(pubkey)) {
                    continue
                }
                val prikey32 = NativeInterface.sharedNativeInterface().bts_gen_private_key_from_wif_privatekey(private_wif.utf8String())
                if (prikey32 == null) {
                    continue
                }
                val encrypted_key = auxAesEncryptToHex(data_encryption_buffer, prikey32)
                if (encrypted_key == null) {
                    continue
                }
                new_private_keys.put(jsonObjectfromKVS("id", new_private_keys.length() + 1, "encrypted_key", encrypted_key, "pubkey", pubkey))
                exist_pubkey_hash.put(pubkey, true)
            }

            //  设置私钥列表。
            final_private_keys = new_private_keys
        }


        //  3、构造 wallet
        val last_modified = genWalletTimeString(Utils.now_ts())
        val new_wallet = old_wallet
        new_wallet.put("last_modified", last_modified)

        //  4、final object
        val final_object = jsonObjectfromKVS("linked_accounts", final_linked_accounts,
                "private_keys", final_private_keys, "wallet", jsonArrayfrom(new_wallet))

        //  5、创建二进制钱包并返回
        return _genFullWalletData(final_object, _wallet_password!!)
    }

    /**
     * 创建完整钱包对象。
     * 直接返回二进制bin。
     */
    fun genFullWalletData(ctx: Context, account_name: String, private_wif_keys: JSONArray, wallet_password: String): ByteArray? {
        val full_wallet_object = genFullWalletObject(ctx, account_name, private_wif_keys, wallet_password)
        if (full_wallet_object == null) {
            return null
        }
        return _genFullWalletData(full_wallet_object, wallet_password)
    }

    private fun _genFullWalletData(full_wallet_object: JSONObject, wallet_password: String): ByteArray? {
        val data = full_wallet_object.toString()
        val entropy = WalletManager.secureRandomByte32Hex()
        return NativeInterface.sharedNativeInterface().bts_save_wallet(data.utf8String(), wallet_password.utf8String(), entropy.utf8String())
    }

    /**
     * (public) 创建完整钱包对象。
     */
    fun genFullWalletObject(ctx: Context, account_name: String, private_wif_keys: JSONArray, wallet_password: String): JSONObject? {
        //  1、随机生成主密码
        val encryption_buffer32 = WalletManager.secureRandomByte32()
        //  2、主密码（用钱包密码加密）
        val encryption_key = auxAesEncryptToHex(wallet_password.utf8String(), encryption_buffer32)
        if (encryption_key == null) {
            return null
        }
        //  3、用主密码加密 owner、active、memo、brain等所有信息。
        val private_keys = JSONArray()
        for (private_wif in private_wif_keys.forin<String>()) {
            if (private_wif == null) {
                continue
            }
            val pubkey = OrgUtils.genBtsAddressFromWifPrivateKey(private_wif)
            assert(pubkey != null)
            if (pubkey == null) {
                return null
            }
            val prikey32 = NativeInterface.sharedNativeInterface().bts_gen_private_key_from_wif_privatekey(private_wif.utf8String())
            if (prikey32 == null) {
                return null
            }
            val encrypted_key = auxAesEncryptToHex(encryption_buffer32, prikey32)
            if (encrypted_key == null) {
                return null
            }
            private_keys.put(jsonObjectfromKVS("id", private_keys.length() + 1, "encrypted_key", encrypted_key, "pubkey", pubkey))
        }

        //  4、生成脑密钥
        val brainkey_plaintext = suggestBrainKey(ctx)
        val brainkey_pubkey = OrgUtils.genBtsAddressFromPrivateKeySeed(brainkey_plaintext)
        val encrypted_brainkey = auxAesEncryptToHex(encryption_buffer32, brainkey_plaintext.utf8String())
        if (encrypted_brainkey == null) {
            return null
        }
        //  5、开始构造完成钱包结构
        val wallet_password_address = OrgUtils.genBtsAddressFromPrivateKeySeed(wallet_password)
        if (wallet_password_address == null) {
            return null
        }
        val created_time = genWalletTimeString(Utils.now_ts())

        //  part02
        var linked_account = JSONObject()
        linked_account.put("chainId", ChainObjectManager.sharedChainObjectManager().grapheneChainID)
        linked_account.put("name", account_name)

        //  part3
        var wallet = JSONObject()
        wallet.put("public_name", "default")
        wallet.put("created", created_time)
        wallet.put("last_modified", created_time)
        //  wallet.put("backup_date", "") //刚创建不存在该字段

        wallet.put("password_pubkey", wallet_password_address)
        wallet.put("encryption_key", encryption_key)
        wallet.put("encrypted_brainkey", encrypted_brainkey)

        wallet.put("brainkey_pubkey", brainkey_pubkey)
        wallet.put("brainkey_sequence", 0)

        wallet.put("chain_id", ChainObjectManager.sharedChainObjectManager().grapheneChainID)
        wallet.put("author", "BTS++")

        //  返回最终对象
        var final_object = JSONObject()
        final_object.put("linked_accounts", jsonArrayfrom(linked_account))
        final_object.put("private_keys", private_keys)
        final_object.put("wallet", jsonArrayfrom(wallet))
        return final_object
    }

    /**
     * (public) 格式化时间戳为BTS官方钱包中的日期格式。格式：2018-07-15T01:45:19.731Z。
     */
    fun genWalletTimeString(time_sec: Long): String {
        //  当前时间
        var ts = time_sec
        if (ts <= 0) {
            ts = Utils.now_ts()
        }
        //  REMARM：日期格式化为 1970-01-01T00:00:00 格式
        val ds = Utils.formatBitsharesTimeString(ts)
        //  默认添加 .000（毫秒） 和 时区 Z。
        return "${ds}.000Z"
    }

    /**
     * (public) 随机生成脑密钥
     */
    fun suggestBrainKey(ctx: Context): String {
        val dictionary = _load_brainkey_dictionary(ctx)
        val randomBuffer = WalletManager.secureRandomByte32()
        val brainkey = mutableListOf<String>()
        val word_count = 16
        val end = word_count * 2
        val base: Double = 65536.0  //  base = pow(2, 16)
        for (i in 0 until end step 2) {
            val num: Int = randomBuffer[i].toUnsignedInt().shl(8) + randomBuffer[i + 1].toUnsignedInt()
            assert(num >= 0)
            //  0...1
            val rndMultiplier = num / base
            assert(rndMultiplier < 1)
            val wordIndex = (dictionary.size * rndMultiplier).toInt()
            assert(wordIndex >= 0 && wordIndex < dictionary.size)
            brainkey.add(dictionary[wordIndex])
        }
        return WalletManager.normalizeBrainKey(brainkey.joinToString(" "))
    }

    /**
     * (private) 辅助函数 - 加载脑密钥词典
     */
    private fun _load_brainkey_dictionary(ctx: Context): List<String> {
        if (_brainkey_dictionary == null) {
            val dic = Utils.readJsonToMap(ctx, "wallet_dictionary_en.json")
            val en = dic.getString("en")
            _brainkey_dictionary = en.split(",")
        }
        return _brainkey_dictionary!!
    }

    /**
     * (public) 辅助 - Aes256加密，并返回16进制字符串，密钥 seed。
     */
    fun auxAesEncryptToHex(seed: ByteArray, data: ByteArray): String? {
        return NativeInterface.sharedNativeInterface().bts_aes256_encrypt_to_hex(seed, data)?.utf8String()
    }

    /**
     * (public) 辅助 - Aes256解密，输入16进制字符串，密钥 seed。
     */
    fun auxAesDecryptFromHex(seed: ByteArray, hexdata: ByteArray): ByteArray? {
        return NativeInterface.sharedNativeInterface().bts_aes256_decrypt_from_hex(seed, hexdata)
    }
}








