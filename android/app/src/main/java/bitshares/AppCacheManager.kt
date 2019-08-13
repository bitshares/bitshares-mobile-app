package bitshares

import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class AppCacheManager {

    enum class EWalletMode(val value: Int) {
        kwmNoWallet(0),                 //  无钱包
        kwmPasswordOnlyMode(1),         //  普通密码模式
        kwmPasswordWithWallet(2),       //  密码登录+钱包模式
        kwmPrivateKeyWithWallet(3),     //  活跃私钥+钱包模式
        kwmFullWalletMode(4),           //  完整钱包模式（兼容官方客户端的钱包格式）
        kwmBrainKeyWithWallet(5),       //  助记词+钱包模式
    }

    companion object {

        private var _spInstanceAppCacheMgr: AppCacheManager? = null
        fun sharedAppCacheManager(): AppCacheManager {
            if (_spInstanceAppCacheMgr == null) {
                _spInstanceAppCacheMgr = AppCacheManager()
            }
            return _spInstanceAppCacheMgr!!
        }
    }

    var _native_caches: JSONObject         //  一些本地缓存信息
    var _wallet_info: JSONObject           //  钱包信息
    var _objectinfo_caches: JSONObject     //  帐号、资产等ID对应的信息缓存（比如 name、precision等）。

    var _favorite_accounts: JSONObject     //  我收藏的帐号列表（关注的） name => @{@"name":@"name", @"id":@"1.2.xx"}
    var _favorite_markets: JSONObject      //  我收藏的市场交易对（关注的）  #{basesymbol}_#{quotesymbol} => @{@"quote":quote_symbol, @"base":base_symbol}
    var _custom_markets: JSONObject        //  自定义的市场列表            #{basesymbol}_#{quotesymbol} => @{@"quote":quote_asset(object),@"base":base_symbol}

    constructor() {
        _native_caches = JSONObject()
        _wallet_info = JSONObject()
        _objectinfo_caches = JSONObject()
        _favorite_accounts = JSONObject()
        _favorite_markets = JSONObject()
        _custom_markets = JSONObject()
    }

    /**
     * 初始化
     */
    fun initload() {
        var fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameMemoryInfosByApp)
        var json = OrgUtils.load_file_as_json(fullname)
        if (json != null) {
            _native_caches = json
        }

        fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameWalletInfoByApp)
        json = OrgUtils.load_file_as_json(fullname)
        if (json != null) {
            _wallet_info = json
        }

        fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameObjectCacheByApp)
        json = OrgUtils.load_file_as_json(fullname)
        if (json != null) {
            _objectinfo_caches = json
        }

        fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameFavAccountsByApp)
        json = OrgUtils.load_file_as_json(fullname)
        if (json != null) {
            _favorite_accounts = json
        }

        fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameFavMarketsByApp)
        json = OrgUtils.load_file_as_json(fullname)
        if (json != null) {
            _favorite_markets = json
        }

        fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameCustomMarketsByApp)
        json = OrgUtils.load_file_as_json(fullname)
        if (json != null) {
            _custom_markets = json
        }
    }

    /**
     * 以下几个方法处理文件写入
     */
    fun saveToFile() {
        saveCacheToFile()
        saveWalletInfoToFile()
        saveObjectCacheToFile()
        saveFavAccountsToFile()
        saveFavMarketsToFile()
        saveCustomMarketsToFile()
    }

    fun saveCacheToFile() {
        val fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameMemoryInfosByApp)
        OrgUtils.write_file_from_json(fullname, _native_caches)
    }

    fun saveWalletInfoToFile() {
        val fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameWalletInfoByApp)
        OrgUtils.write_file_from_json(fullname, _wallet_info)
    }

    fun saveObjectCacheToFile() {
        val fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameObjectCacheByApp)
        OrgUtils.write_file_from_json(fullname, _objectinfo_caches)
    }

    fun saveFavAccountsToFile() {
        val fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameFavAccountsByApp)
        OrgUtils.write_file_from_json(fullname, _favorite_accounts)
    }

    fun saveFavMarketsToFile() {
        val fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameFavMarketsByApp)
        OrgUtils.write_file_from_json(fullname, _favorite_markets)
    }

    fun saveCustomMarketsToFile() {
        val fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameCustomMarketsByApp)
        OrgUtils.write_file_from_json(fullname, _custom_markets)
    }

    /**
     * for native KV caches
     */
    fun getPref(key: String, default_value: Any? = null): Any? {
        if (_native_caches.has(key)) {
            return _native_caches.get(key)
        } else {
            return default_value
        }
    }

    fun setPref(key: String, value: Any): AppCacheManager {
        _native_caches.put(key, value)
        return this
    }

    fun deletePref(key: String): AppCacheManager {
        _native_caches.remove(key)
        return this
    }

    /**
     * 对象存储和获取
     */
    fun update_object_cache(oid: String?, obj: JSONObject): AppCacheManager {
        if (oid == null) {
            return this
        }
        //  REMARK：格式   object_id => {:expire_ts, :cache_object}
        _objectinfo_caches.put(oid, jsonObjectfromKVS("expire_ts", Utils.now_ts() + kBTSObjectCacheExpireTime, "cache_object", obj))
        return this
    }

    /**
     * 获取缓存的区块链对象 REMARK：所有缓存对象默认有个过期日期，如果 now_ts 小于等于0则不判断过期日期。
     */
    fun get_object_cache_ts(oid: String?, now_ts: Long): JSONObject? {
        if (oid == null) {
            return null
        }
        //  对象不存在
        val item = _objectinfo_caches.optJSONObject(oid)
        if (item == null) {
            return null
        }
        //  REMARK：now_ts 小于等于0则不判断是否过期。
        if (now_ts > 0) {
            val expire_ts = item.getLong("expire_ts")
            if (now_ts >= expire_ts) {
                //  REMARK：缓存已经过期了，则删除缓存。
                _objectinfo_caches.remove(oid)
                return null
            }
        }
        //  返回缓存对象
        return item.optJSONObject("cache_object")
    }

    fun get_object_cache(oid: String): JSONObject? {
        return get_object_cache_ts(oid, Utils.now_ts())
    }

    /**
     * 账号关注相关数据
     */
    fun get_all_fav_accounts(): JSONObject {
        return _favorite_accounts
    }

    fun set_fav_account(account_info: JSONObject?): AppCacheManager {
        if (account_info != null) {
            val oid = account_info.optString("id")
            val name = account_info.optString("name")
            if (oid != null && name != null) {
                _favorite_accounts.put(name, account_info)
            }
        }
        return this
    }

    fun remove_fav_account(account_name: String?) {
        if (account_name == null) {
            return
        }
        _favorite_accounts.remove(account_name)
    }

    /**
     * 自选市场相关数据
     */
    fun get_all_fav_markets(): JSONObject {
        return _favorite_markets
    }

    fun is_fav_market(quote_symbol: String?, base_symbol: String?): Boolean {
        if (quote_symbol != null && base_symbol != null) {
            val pair = "${base_symbol}_${quote_symbol}"
            val fav_item = _favorite_markets.optJSONObject(pair)
            if (fav_item != null) {
                return true
            }
        }
        return false
    }

    fun set_fav_markets(quote_symbol: String?, base_symbol: String?): AppCacheManager {
        if (quote_symbol != null && base_symbol != null) {
            val pair = "${base_symbol}_${quote_symbol}"
            _favorite_markets.put(pair, jsonObjectfromKVS("base", base_symbol, "quote", quote_symbol))
        }
        return this
    }

    fun remove_fav_markets(fav_item: JSONObject?) {
        if (fav_item == null) {
            return
        }
        remove_fav_markets(fav_item.getString("quote"), fav_item.getString("base"))
    }

    fun remove_fav_markets(quote_symbol: String?, base_symbol: String?) {
        if (quote_symbol != null && base_symbol != null) {
            val pair = "${base_symbol}_${quote_symbol}"
            _favorite_markets.remove(pair)
        }
    }

    /**
     * 自定义交易对相关数据
     */
    fun get_all_custom_markets(): JSONObject {
        return _custom_markets
    }

    fun is_custom_market(quote_symbol: String?, base_symbol: String?): Boolean {
        if (quote_symbol != null && base_symbol != null) {
            val pair = "${base_symbol}_${quote_symbol}"
            val custom_item = _custom_markets.optJSONObject(pair)
            if (custom_item != null) {
                return true
            }
        }
        return false
    }

    fun set_custom_markets(quote_asset: JSONObject?, base_symbol: String?): AppCacheManager {
        if (quote_asset != null && base_symbol != null) {
            val quote_symbol = quote_asset.getString("symbol")
            val pair = "${base_symbol}_${quote_symbol}"
            _custom_markets.put(pair, jsonObjectfromKVS("base", base_symbol, "quote", quote_asset))
        }
        return this
    }

    fun remove_custom_markets(custom_item: JSONObject?): AppCacheManager {
        if (custom_item == null) {
            return this
        }
        remove_custom_markets(custom_item.getJSONObject("quote").getString("symbol"), custom_item.getString("base"))
        return this
    }

    fun remove_custom_markets(quote_symbol: String?, base_symbol: String?): AppCacheManager {
        if (quote_symbol != null && base_symbol != null) {
            val pair = "${base_symbol}_${quote_symbol}"
            _custom_markets.remove(pair)
        }
        return this
    }

    /**
     * 钱包相关数据
     */
    fun getWalletInfo(): JSONObject {
        return _wallet_info
    }

    fun removeWalletInfo() {
        _wallet_info = JSONObject()
        saveWalletInfoToFile()
    }

    /**
     * (public) 更新本地钱包帐号信息
     * walletMode      - 帐号模式
     * accountInfo     - 帐号完整信息（可能为空、注册成但查询失败时则为空。）
     * ccountName     - 帐号名（不能为空）
     * fullWalletBin   - 钱包二进制bin文件（除了帐号模式以外都存在）
     */
    fun setWalletInfo(walletMode: Int, fullAccountInfo: JSONObject?, account_name: String, full_wallet_bin: ByteArray?) {
        _wallet_info = JSONObject()
        //  基本字段（不能为空）
        _wallet_info.put("kWalletMode", walletMode)
        //  当前账号信息（活跃账号信息）
        _wallet_info.put("kAccountName", account_name)
        //  附加信息（可为空）
        if (fullAccountInfo != null) {
            _wallet_info.put("kAccountInfo", fullAccountInfo)
        }
        //  钱包BIN文件信息
        if (full_wallet_bin != null) {
            _wallet_info.put("kAccountDataList", JSONArray())
            _wallet_info.put("kFullWalletBin", full_wallet_bin.hexEncode())
        }
        //  保存
        saveWalletInfoToFile()
    }

    /**
     *  (public) 设置钱包中当前活跃账号（当前操作的账号）
     */
    fun setWalletCurrentAccount(currAccountName: String, fullAccountData: JSONObject) {
        assert(fullAccountData.getJSONObject("account").getString("name") == currAccountName)
        //  设置当前账号信息
        _wallet_info.put("kAccountName", currAccountName)
        _wallet_info.put("kAccountInfo", fullAccountData)

        //  保存
        saveWalletInfoToFile()
    }

    /**
     *  (public) 保存钱包中的账号信息（和BIN中的账号信息应该同步）
     */
    fun setWalletAccountDataList(accountDataList: JSONArray) {
        accountDataList.forEach<JSONObject> {
            val accountData = it!!
            assert(accountData.has("id"))
            assert(accountData.has("active"))
            assert(accountData.has("owner"))
        }

        //  设置账号信息
        _wallet_info.put("kAccountDataList", accountDataList)

        //  保存
        saveWalletInfoToFile()
    }

    /**
     *  更新钱包BIN信息
     */
    fun updateWalletBin(full_wallet_bin: ByteArray) {
        assert(_wallet_info.getInt("kWalletMode") != EWalletMode.kwmNoWallet.value)
        assert(_wallet_info.getInt("kWalletMode") != EWalletMode.kwmPasswordOnlyMode.value)
        _wallet_info.put("kFullWalletBin", full_wallet_bin.hexEncode())
        //  保存
        saveWalletInfoToFile()
    }

    /**
     * (public) 更新本地帐号数据
     */
    fun updateWalletAccountInfo(account_info: JSONObject) {
        if (_wallet_info.getInt("kWalletMode") == EWalletMode.kwmNoWallet.value) {
            return
        }
        _wallet_info.put("kAccountInfo", account_info)
        //  保存
        saveWalletInfoToFile()
    }

    /**
     *  备份钱包bin到web目录供用户下载。（也供 iTunes 备份）
     *  hasDatePrefix - 备份文件是否添加日期前缀（在账号管理处手动备份等则添加，其他自动备份等不用添加）
     */
    fun autoBackupWalletToWebdir(hasDatePrefix: Boolean): Boolean {
        val hex_wallet_bin = _wallet_info.optString("kFullWalletBin")
        if (hex_wallet_bin == "") {
            return false
        }

        var account_name = _wallet_info.optString("kAccountName")
        if (account_name == "") {
            account_name = "default"
        }

        var final_wallet_name = account_name
        val account_data_hash = WalletManager.sharedWalletManager().getAllAccountDataHash(true)
        if (account_data_hash.length() >= 2) {
            //  REMARK：多账号时钱包默认名字。
            final_wallet_name = "multi_accounts_wallet"
        }

        //  备份到文件
        val wallet_bin = hex_wallet_bin.hexDecode()

        var filename: String
        if (hasDatePrefix) {
            val prefix = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
            filename = "${prefix}_${final_wallet_name}.bin"
        } else {
            filename = "${final_wallet_name}.bin"
        }

        val fullpath = "${OrgUtils.getAppDirWebServerImport()}${filename}"

        //  [统计]
        btsppLogCustom("auto_backupwallet", jsonObjectfromKVS("final_wallet_name", final_wallet_name, "has_prefix", hasDatePrefix))
        return OrgUtils.write_file(fullpath, wallet_bin)
    }
}