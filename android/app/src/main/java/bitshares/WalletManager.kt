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

        /**
         *  (public) 随机生成 32 个英文字符列表
         *  check_sum_prefix - 可在助记词中添加4个字符的校验码（check_sum_prefix会参与校验码计算。用于区分不同用途的助记词，比如密码用，隐私账户用。）
         */
        fun randomGenerateEnglishWord_N32(check_sum_prefix: String?): MutableList<String> {
            val word_list = englishPasswordCharacter()
            val n_word_list = word_list.length()
            val randomBuffer = secureRandomByte32()

            val brainkey = mutableListOf<String>()
            val base = 256.0  //  base = pow(2, 16)
            for (i in 0 until 32) {
                brainkey.add(_fetchBrainKeyWord(word_list, n_word_list, randomBuffer[i].toUnsignedInt(), base))
            }

            //  REMARK：助记词中添加4字节校验码。（4个字符）
            if (check_sum_prefix != null && check_sum_prefix.isNotEmpty()) {
                val new_brainkey = brainkey.subList(0, brainkey.size - 4)
                val real_brainkey = new_brainkey.joinToString("")
                //  check_sum_prefix + real_brainkey
                val check_sum_full_string = check_sum_prefix + real_brainkey
                val checksum = sha256(check_sum_full_string.utf8String())
                //  4字节checksum转换为助记词字符。
                for (i in 0 until 4) {
                    new_brainkey.add(_fetchBrainKeyWord(word_list, n_word_list, checksum[i].toUnsignedInt(), base))
                }
                return new_brainkey
            }

            return brainkey
        }

        /**
         *  (public) 随机生成 16 个中文汉字列表
         *  check_sum_prefix - 可在助记词中添加2个汉字的校验码（check_sum_prefix会参与校验码计算。用于区分不同用途的助记词，比如密码用，隐私账户用。）
         */
        fun randomGenerateChineseWord_N16(check_sum_prefix: String?): MutableList<String> {
            val word_list = chineseWordList()
            val n_word_list = word_list.length()
            val randomBuffer = secureRandomByte32()

            val brainkey = mutableListOf<String>()
            val word_count = 16
            val end = word_count * 2
            val base = 65536.0  //  base = pow(2, 16)
            for (i in 0 until end step 2) {
                val num: Int = randomBuffer[i].toUnsignedInt().shl(8) + randomBuffer[i + 1].toUnsignedInt()
                assert(num >= 0)
                brainkey.add(_fetchBrainKeyWord(word_list, n_word_list, num, base))
            }

            //  REMARK：助记词中添加4字节校验码。（2个汉字）
            if (check_sum_prefix != null && check_sum_prefix.isNotEmpty()) {
                val new_brainkey = brainkey.subList(0, brainkey.size - 2)
                val real_brainkey = new_brainkey.joinToString("")
                //  check_sum_prefix + real_brainkey
                val check_sum_full_string = check_sum_prefix + real_brainkey
                val checksum = sha256(check_sum_full_string.utf8String())
                //  4字节checksum转换为助记词字符。
                for (i in 0 until 4 step 2) {
                    val num: Int = checksum[i].toUnsignedInt().shl(8) + checksum[i + 1].toUnsignedInt()
                    assert(num >= 0)
                    new_brainkey.add(_fetchBrainKeyWord(word_list, n_word_list, num, base))
                }
                return new_brainkey
            }

            return brainkey
        }

        /**
         *  (public) 是否是有效的隐私交易（隐私账户）助记词。
         */
        fun isValidStealthTransferBrainKey(brain_key: String?, check_sum_prefix: String): Boolean {
            if (brain_key == null || brain_key.isEmpty()) {
                return false
            }
            val d_brain_key = brain_key.utf8String()
            return if (d_brain_key.size == 32 && brain_key.length == 32) {
                _verifyBrainKeyCheckSum(brain_key, 1, englishPasswordCharacter(), check_sum_prefix)
            } else if (d_brain_key.size == 48 && brain_key.length == 16) {
                _verifyBrainKeyCheckSum(brain_key, 2, chineseWordList(), check_sum_prefix)
            } else {
                false
            }
        }

        /**
         *  (private) 验证助记词的checksum。
         *  REMARK：助记词生成时的字符表不能修改，否则会验证失败。
         */
        private fun _verifyBrainKeyCheckSum(brain_key: String, char_per_byte: Int, word_list: JSONArray, check_sum_prefix: String): Boolean {
            assert(char_per_byte == 1 || char_per_byte == 2)

            //  验证码字节数 和 验证码字符数
            val check_sum_bytes = 4
            val check_sum_char_num = check_sum_bytes / char_per_byte
            assert(check_sum_char_num * char_per_byte == check_sum_bytes)

            //  计算checksum：check_sum_prefix + real_brainkey
            val check_sum_index = brain_key.length - check_sum_char_num
            val real_brainkey = brain_key.substring(0, check_sum_index)
            val check_sum_full_string = check_sum_prefix + real_brainkey
            val checksum = sha256(check_sum_full_string.utf8String())

            //  checksum的前 4 字节转为助记词字符。
            val base = Math.pow(2.0, char_per_byte * 8.0)
            val check_sum_array = mutableListOf<String>()
            val n_word_list = word_list.length()

            for (i in 0 until check_sum_bytes step char_per_byte) {
                val num = if (char_per_byte == 1) {
                    checksum[i].toUnsignedInt()
                } else {
                    checksum[i].toUnsignedInt().shl(8) + checksum[i + 1].toUnsignedInt()
                }
                check_sum_array.add(_fetchBrainKeyWord(word_list, n_word_list, num, base))
            }

            //  验证助记词中的结尾校验码字符是否和计算的校验码字符相同。
            val check_sum = brain_key.substring(check_sum_index)
            return check_sum_array.joinToString("") == check_sum
        }

        /**
         *  (private) 获取助记词单个字符。
         */
        private fun _fetchBrainKeyWord(word_list: JSONArray, n_word_list: Int, value: Int, base: Double): String {
            //  0...1
            val rndMultiplier = value / base
            assert(rndMultiplier < 1)
            val wordIndex = (n_word_list * rndMultiplier).toInt()
            assert(wordIndex < n_word_list)
            return word_list.getString(wordIndex)
        }

        private var _words_english: JSONArray? = null
        private var _words_chinese: JSONArray? = null

        private fun englishPasswordCharacter(): JSONArray {
            if (_words_english == null) {
                _words_english = jsonArrayfrom("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
            }
            return _words_english!!
        }

        private fun chineseWordList(): JSONArray {
            if (_words_chinese == null) {
                _words_chinese = jsonArrayfrom("的", "一", "是", "在", "不", "了", "有", "和", "人", "这", "中", "大", "为", "上", "个", "国", "我", "以", "要", "他", "时", "来", "用", "们", "生", "到", "作", "地", "于", "出", "就", "分", "对", "成", "会", "可", "主", "发", "年", "动", "同", "工", "也", "能", "下", "过", "子", "说", "产", "种", "面", "而", "方", "后", "多", "定", "行", "学", "法", "所", "民", "得", "经", "十", "三", "之", "进", "着", "等", "部", "度", "家", "电", "力", "里", "如", "水", "化", "高", "自", "二", "理", "起", "小", "物", "现", "实", "加", "量", "都", "两", "体", "制", "机", "当", "使", "点", "从", "业", "本", "去", "把", "性", "好", "应", "开", "它", "合", "还", "因", "由", "其", "些", "然", "前", "外", "天", "政", "四", "日", "那", "社", "义", "事", "平", "形", "相", "全", "表", "间", "样", "与", "关", "各", "重", "新", "线", "内", "数", "正", "心", "反", "你", "明", "看", "原", "又", "么", "利", "比", "或", "但", "质", "气", "第", "向", "道", "命", "此", "变", "条", "只", "没", "结", "解", "问", "意", "建", "月", "公", "无", "系", "军", "很", "情", "者", "最", "立", "代", "想", "已", "通", "并", "提", "直", "题", "党", "程", "展", "五", "果", "料", "象", "员", "革", "位", "入", "常", "文", "总", "次", "品", "式", "活", "设", "及", "管", "特", "件", "长", "求", "老", "头", "基", "资", "边", "流", "路", "级", "少", "图", "山", "统", "接", "知", "较", "将", "组", "见", "计", "别", "她", "手", "角", "期", "根", "论", "运", "农", "指", "几", "九", "区", "强", "放", "决", "西", "被", "干", "做", "必", "战", "先", "回", "则", "任", "取", "据", "处", "队", "南", "给", "色", "光", "门", "即", "保", "治", "北", "造", "百", "规", "热", "领", "七", "海", "口", "东", "导", "器", "压", "志", "世", "金", "增", "争", "济", "阶", "油", "思", "术", "极", "交", "受", "联", "什", "认", "六", "共", "权", "收", "证", "改", "清", "美", "再", "采", "转", "更", "单", "风", "切", "打", "白", "教", "速", "花", "带", "安", "场", "身", "车", "例", "真", "务", "具", "万", "每", "目", "至", "达", "走", "积", "示", "议", "声", "报", "斗", "完", "类", "八", "离", "华", "名", "确", "才", "科", "张", "信", "马", "节", "话", "米", "整", "空", "元", "况", "今", "集", "温", "传", "土", "许", "步", "群", "广", "石", "记", "需", "段", "研", "界", "拉", "林", "律", "叫", "且", "究", "观", "越", "织", "装", "影", "算", "低", "持", "音", "众", "书", "布", "复", "容", "儿", "须", "际", "商", "非", "验", "连", "断", "深", "难", "近", "矿", "千", "周", "委", "素", "技", "备", "半", "办", "青", "省", "列", "习", "响", "约", "支", "般", "史", "感", "劳", "便", "团", "往", "酸", "历", "市", "克", "何", "除", "消", "构", "府", "称", "太", "准", "精", "值", "号", "率", "族", "维", "划", "选", "标", "写", "存", "候", "毛", "亲", "快", "效", "斯", "院", "查", "江", "型", "眼", "王", "按", "格", "养", "易", "置", "派", "层", "片", "始", "却", "专", "状", "育", "厂", "京", "识", "适", "属", "圆", "包", "火", "住", "调", "满", "县", "局", "照", "参", "红", "细", "引", "听", "该", "铁", "价", "严", "首", "底", "液", "官", "德", "随", "病", "苏", "失", "尔", "死", "讲", "配", "女", "黄", "推", "显", "谈", "罪", "神", "艺", "呢", "席", "含", "企", "望", "密", "批", "营", "项", "防", "举", "球", "英", "氧", "势", "告", "李", "台", "落", "木", "帮", "轮", "破", "亚", "师", "围", "注", "远", "字", "材", "排", "供", "河", "态", "封", "另", "施", "减", "树", "溶", "怎", "止", "案", "言", "士", "均", "武", "固", "叶", "鱼", "波", "视", "仅", "费", "紧", "爱", "左", "章", "早", "朝", "害", "续", "轻", "服", "试", "食", "充", "兵", "源", "判", "护", "司", "足", "某", "练", "差", "致", "板", "田", "降", "黑", "犯", "负", "击", "范", "继", "兴", "似", "余", "坚", "曲", "输", "修", "故", "城", "夫", "够", "送", "笔", "船", "占", "右", "财", "吃", "富", "春", "职", "觉", "汉", "画", "功", "巴", "跟", "虽", "杂", "飞", "检", "吸", "助", "升", "阳", "互", "初", "创", "抗", "考", "投", "坏", "策", "古", "径", "换", "未", "跑", "留", "钢", "曾", "端", "责", "站", "简", "述", "钱", "副", "尽", "帝", "射", "草", "冲", "承", "独", "令", "限", "阿", "宣", "环", "双", "请", "超", "微", "让", "控", "州", "良", "轴", "找", "否", "纪", "益", "依", "优", "顶", "础", "载", "倒", "房", "突", "坐", "粉", "敌", "略", "客", "袁", "冷", "胜", "绝", "析", "块", "剂", "测", "丝", "协", "诉", "念", "陈", "仍", "罗", "盐", "友", "洋", "错", "苦", "夜", "刑", "移", "频", "逐", "靠", "混", "母", "短", "皮", "终", "聚", "汽", "村", "云", "哪", "既", "距", "卫", "停", "烈", "央", "察", "烧", "迅", "境", "若", "印", "洲", "刻", "括", "激", "孔", "搞", "甚", "室", "待", "核", "校", "散", "侵", "吧", "甲", "游", "久", "菜", "味", "旧", "模", "湖", "货", "损", "预", "阻", "毫", "普", "稳", "乙", "妈", "植", "息", "扩", "银", "语", "挥", "酒", "守", "拿", "序", "纸", "医", "缺", "雨", "吗", "针", "刘", "啊", "急", "唱", "误", "训", "愿", "审", "附", "获", "茶", "鲜", "粮", "斤", "孩", "脱", "硫", "肥", "善", "龙", "演", "父", "渐", "血", "欢", "械", "掌", "歌", "沙", "刚", "攻", "谓", "盾", "讨", "晚", "粒", "乱", "燃", "矛", "乎", "杀", "药", "宁", "鲁", "贵", "钟", "煤", "读", "班", "伯", "香", "介", "迫", "句", "丰", "培", "握", "兰", "担", "弦", "蛋", "沉", "假", "穿", "执", "答", "乐", "谁", "顺", "烟", "缩", "征", "脸", "喜", "松", "脚", "困", "异", "免", "背", "星", "福", "买", "染", "井", "概", "慢", "怕", "磁", "倍", "祖", "皇", "促", "静", "补", "评", "翻", "肉", "践", "尼", "衣", "宽", "扬", "棉", "希", "伤", "操", "垂", "秋", "宜", "氢", "套", "督", "振", "架", "亮", "末", "宪", "庆", "编", "牛", "触", "映", "雷", "销", "诗", "座", "居", "抓", "裂", "胞", "呼", "娘", "景", "威", "绿", "晶", "厚", "盟", "衡", "鸡", "孙", "延", "危", "胶", "屋", "乡", "临", "陆", "顾", "掉", "呀", "灯", "岁", "措", "束", "耐", "剧", "玉", "赵", "跳", "哥", "季", "课", "凯", "胡", "额", "款", "绍", "卷", "齐", "伟", "蒸", "殖", "永", "宗", "苗", "川", "炉", "岩", "弱", "零", "杨", "奏", "沿", "露", "杆", "探", "滑", "镇", "饭", "浓", "航", "怀", "赶", "库", "夺", "伊", "灵", "税", "途", "灭", "赛", "归", "召", "鼓", "播", "盘", "裁", "险", "康", "唯", "录", "菌", "纯", "借", "糖", "盖", "横", "符", "私", "努", "堂", "域", "枪", "润", "幅", "哈", "竟", "熟", "虫", "泽", "脑", "壤", "碳", "欧", "遍", "侧", "寨", "敢", "彻", "虑", "斜", "薄", "庭", "纳", "弹", "饲", "伸", "折", "麦", "湿", "暗", "荷", "瓦", "塞", "床", "筑", "恶", "户", "访", "塔", "奇", "透", "梁", "刀", "旋", "迹", "卡", "氯", "遇", "份", "毒", "泥", "退", "洗", "摆", "灰", "彩", "卖", "耗", "夏", "择", "忙", "铜", "献", "硬", "予", "繁", "圈", "雪", "函", "亦", "抽", "篇", "阵", "阴", "丁", "尺", "追", "堆", "雄", "迎", "泛", "爸", "楼", "避", "谋", "吨", "野", "猪", "旗", "累", "偏", "典", "馆", "索", "秦", "脂", "潮", "爷", "豆", "忽", "托", "惊", "塑", "遗", "愈", "朱", "替", "纤", "粗", "倾", "尚", "痛", "楚", "谢", "奋", "购", "磨", "君", "池", "旁", "碎", "骨", "监", "捕", "弟", "暴", "割", "贯", "殊", "释", "词", "亡", "壁", "顿", "宝", "午", "尘", "闻", "揭", "炮", "残", "冬", "桥", "妇", "警", "综", "招", "吴", "付", "浮", "遭", "徐", "您", "摇", "谷", "赞", "箱", "隔", "订", "男", "吹", "园", "纷", "唐", "败", "宋", "玻", "巨", "耕", "坦", "荣", "闭", "湾", "键", "凡", "驻", "锅", "救", "恩", "剥", "凝", "碱", "齿", "截", "炼", "麻", "纺", "禁", "废", "盛", "版", "缓", "净", "睛", "昌", "婚", "涉", "筒", "嘴", "插", "岸", "朗", "庄", "街", "藏", "姑", "贸", "腐", "奴", "啦", "惯", "乘", "伙", "恢", "匀", "纱", "扎", "辩", "耳", "彪", "臣", "亿", "璃", "抵", "脉", "秀", "萨", "俄", "网", "舞", "店", "喷", "纵", "寸", "汗", "挂", "洪", "贺", "闪", "柬", "爆", "烯", "津", "稻", "墙", "软", "勇", "像", "滚", "厘", "蒙", "芳", "肯", "坡", "柱", "荡", "腿", "仪", "旅", "尾", "轧", "冰", "贡", "登", "黎", "削", "钻", "勒", "逃", "障", "氨", "郭", "峰", "币", "港", "伏", "轨", "亩", "毕", "擦", "莫", "刺", "浪", "秘", "援", "株", "健", "售", "股", "岛", "甘", "泡", "睡", "童", "铸", "汤", "阀", "休", "汇", "舍", "牧", "绕", "炸", "哲", "磷", "绩", "朋", "淡", "尖", "启", "陷", "柴", "呈", "徒", "颜", "泪", "稍", "忘", "泵", "蓝", "拖", "洞", "授", "镜", "辛", "壮", "锋", "贫", "虚", "弯", "摩", "泰", "幼", "廷", "尊", "窗", "纲", "弄", "隶", "疑", "氏", "宫", "姐", "震", "瑞", "怪", "尤", "琴", "循", "描", "膜", "违", "夹", "腰", "缘", "珠", "穷", "森", "枝", "竹", "沟", "催", "绳", "忆", "邦", "剩", "幸", "浆", "栏", "拥", "牙", "贮", "礼", "滤", "钠", "纹", "罢", "拍", "咱", "喊", "袖", "埃", "勤", "罚", "焦", "潜", "伍", "墨", "欲", "缝", "姓", "刊", "饱", "仿", "奖", "铝", "鬼", "丽", "跨", "默", "挖", "链", "扫", "喝", "袋", "炭", "污", "幕", "诸", "弧", "励", "梅", "奶", "洁", "灾", "舟", "鉴", "苯", "讼", "抱", "毁", "懂", "寒", "智", "埔", "寄", "届", "跃", "渡", "挑", "丹", "艰", "贝", "碰", "拔", "爹", "戴", "码", "梦", "芽", "熔", "赤", "渔", "哭", "敬", "颗", "奔", "铅", "仲", "虎", "稀", "妹", "乏", "珍", "申", "桌", "遵", "允", "隆", "螺", "仓", "魏", "锐", "晓", "氮", "兼", "隐", "碍", "赫", "拨", "忠", "肃", "缸", "牵", "抢", "博", "巧", "壳", "兄", "杜", "讯", "诚", "碧", "祥", "柯", "页", "巡", "矩", "悲", "灌", "龄", "伦", "票", "寻", "桂", "铺", "圣", "恐", "恰", "郑", "趣", "抬", "荒", "腾", "贴", "柔", "滴", "猛", "阔", "辆", "妻", "填", "撤", "储", "签", "闹", "扰", "紫", "砂", "递", "戏", "吊", "陶", "伐", "喂", "疗", "瓶", "婆", "抚", "臂", "摸", "忍", "虾", "蜡", "邻", "胸", "巩", "挤", "偶", "弃", "槽", "劲", "乳", "邓", "吉", "仁", "烂", "砖", "租", "乌", "舰", "伴", "瓜", "浅", "丙", "暂", "燥", "橡", "柳", "迷", "暖", "牌", "秧", "胆", "详", "簧", "踏", "瓷", "谱", "呆", "宾", "糊", "洛", "辉", "愤", "竞", "隙", "怒", "粘", "乃", "绪", "肩", "籍", "敏", "涂", "熙", "皆", "侦", "悬", "掘", "享", "纠", "醒", "狂", "锁", "淀", "恨", "牲", "霸", "爬", "赏", "逆", "玩", "陵", "祝", "秒", "浙", "貌", "役", "彼", "悉", "鸭", "趋", "凤", "晨", "畜", "辈", "秩", "卵", "署", "梯", "炎", "滩", "棋", "驱", "筛", "峡", "冒", "啥", "寿", "译", "浸", "泉", "帽", "迟", "硅", "疆", "贷", "漏", "稿", "冠", "嫩", "胁", "芯", "牢", "叛", "蚀", "奥", "鸣", "岭", "羊", "凭", "串", "塘", "绘", "酵", "融", "盆", "锡", "庙", "筹", "冻", "辅", "摄", "袭", "筋", "拒", "僚", "旱", "钾", "鸟", "漆", "沈", "眉", "疏", "添", "棒", "穗", "硝", "韩", "逼", "扭", "侨", "凉", "挺", "碗", "栽", "炒", "杯", "患", "馏", "劝", "豪", "辽", "勃", "鸿", "旦", "吏", "拜", "狗", "埋", "辊", "掩", "饮", "搬", "骂", "辞", "勾", "扣", "估", "蒋", "绒", "雾", "丈", "朵", "姆", "拟", "宇", "辑", "陕", "雕", "偿", "蓄", "崇", "剪", "倡", "厅", "咬", "驶", "薯", "刷", "斥", "番", "赋", "奉", "佛", "浇", "漫", "曼", "扇", "钙", "桃", "扶", "仔", "返", "俗", "亏", "腔", "鞋", "棱", "覆", "框", "悄", "叔", "撞", "骗", "勘", "旺", "沸", "孤", "吐", "孟", "渠", "屈", "疾", "妙", "惜", "仰", "狠", "胀", "谐", "抛", "霉", "桑", "岗", "嘛", "衰", "盗", "渗", "脏", "赖", "涌", "甜", "曹", "阅", "肌", "哩", "厉", "烃", "纬", "毅", "昨", "伪", "症", "煮", "叹", "钉", "搭", "茎", "笼", "酷", "偷", "弓", "锥", "恒", "杰", "坑", "鼻", "翼", "纶", "叙", "狱", "逮", "罐", "络", "棚", "抑", "膨", "蔬", "寺", "骤", "穆", "冶", "枯", "册", "尸", "凸", "绅", "坯", "牺", "焰", "轰", "欣", "晋", "瘦", "御", "锭", "锦", "丧", "旬", "锻", "垄", "搜", "扑", "邀", "亭", "酯", "迈", "舒", "脆", "酶", "闲", "忧", "酚", "顽", "羽", "涨", "卸", "仗", "陪", "辟", "惩", "杭", "姚", "肚", "捉", "飘", "漂", "昆", "欺", "吾", "郎", "烷", "汁", "呵", "饰", "萧", "雅", "邮", "迁", "燕", "撒", "姻", "赴", "宴", "烦", "债", "帐", "斑", "铃", "旨", "醇", "董", "饼", "雏", "姿", "拌", "傅", "腹", "妥", "揉", "贤", "拆", "歪", "葡", "胺", "丢", "浩", "徽", "昂", "垫", "挡", "览", "贪", "慰", "缴", "汪", "慌", "冯", "诺", "姜", "谊", "凶", "劣", "诬", "耀", "昏", "躺", "盈", "骑", "乔", "溪", "丛", "卢", "抹", "闷", "咨", "刮", "驾", "缆", "悟", "摘", "铒", "掷", "颇", "幻", "柄", "惠", "惨", "佳", "仇", "腊", "窝", "涤", "剑", "瞧", "堡", "泼", "葱", "罩", "霍", "捞", "胎", "苍", "滨", "俩", "捅", "湘", "砍", "霞", "邵", "萄", "疯", "淮", "遂", "熊", "粪", "烘", "宿", "档", "戈", "驳", "嫂", "裕", "徙", "箭", "捐", "肠", "撑", "晒", "辨", "殿", "莲", "摊", "搅", "酱", "屏", "疫", "哀", "蔡", "堵", "沫", "皱", "畅", "叠", "阁", "莱", "敲", "辖", "钩", "痕", "坝", "巷", "饿", "祸", "丘", "玄", "溜", "曰", "逻", "彭", "尝", "卿", "妨", "艇", "吞", "韦", "怨", "矮", "歇")
            }
            return _words_chinese!!
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
     *  (public) 创建新钱包。
     *  current_full_account_data   - 钱包当前账号  REMARK：创建后的当前账号，需要有完整的active权限。
     *  pub_pri_keys_hash           - 需要导入的私钥Hash
     *  append_memory_key           - 导入内存中已经存在的私钥 REMARK：需要钱包已解锁。
     *  extra_account_name_list     - 除了当前账号外的其他需要同时导入的账号名。
     *  pWalletPassword             - 新钱包的密码。
     *  login_mode                  - 模式。
     *  login_desc                  - 描述信息。
     */
    fun createNewWallet(ctx: Context, current_full_account_data: JSONObject, pub_pri_keys_hash: JSONObject, append_memory_key: Boolean,
                        extra_account_name_list: JSONArray?, pWalletPassword: String, login_mode: AppCacheManager.EWalletMode, login_desc: String? = null): EImportToWalletStatus {
        val account = current_full_account_data.getJSONObject("account")
        val currentAccountName = account.getString("name")

        //  合并所有KEY（参数中和内存中）
        if (append_memory_key) {
            assert(!isLocked())
            _private_keys_hash.keys().forEach { pubkey ->
                val prikey = _private_keys_hash.getString(pubkey)
                pub_pri_keys_hash.put(pubkey, prikey)
            }
        }

        //  检测当前账号是否有完整的active权限。
        val account_active = account.getJSONObject("active")
        val status = WalletManager.calcPermissionStatus(account_active, pub_pri_keys_hash)
        if (status == EAccountPermissionStatus.EAPS_NO_PERMISSION) {
            return EImportToWalletStatus.eitws_no_permission
        } else if (status == EAccountPermissionStatus.EAPS_PARTIAL_PERMISSION) {
            return EImportToWalletStatus.eitws_partial_permission
        }

        val pAppCache = AppCacheManager.sharedAppCacheManager()

        //  获取所有需要导入到钱包中的账号名列表。
        val account_name_list = JSONArray()
        account_name_list.put(currentAccountName)
        if (extra_account_name_list != null && extra_account_name_list.length() > 0) {
            val extraNameHash = JSONObject()
            extra_account_name_list.forEach<String> { name ->
                if (name!! != currentAccountName) {
                    extraNameHash.put(name, true)
                }
            }
            account_name_list.putAll(extraNameHash.keys().toJSONArray())
        }

        //  创建钱包
        val full_wallet_bin = genFullWalletData(ctx, account_name_list, pub_pri_keys_hash.values(), pWalletPassword)

        //  保存钱包信息
        pAppCache.setWalletInfo(login_mode.value, current_full_account_data, currentAccountName, full_wallet_bin)
        pAppCache.autoBackupWalletToWebdir(false)

        //  导入成功 用交易密码 直接解锁。
        val unlockInfos = unLock(pWalletPassword, ctx)
        assert(unlockInfos.getBoolean("unlockSuccess") && unlockInfos.optBoolean("haveActivePermission"))

        //  [统计]
        btsppLogCustom("loginEvent", jsonObjectfromKVS("mode", login_mode.value, "desc", login_desc
                ?: "unknown"))

        //  成功
        return EImportToWalletStatus.eitws_ok
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

    /*
     *  (public) 注销登录逻辑。内存钱包锁定、导入钱包删除。
     */
    fun processLogout() {
        OtcManager.sharedOtcManager().processLogout()
        Lock()
        AppCacheManager.sharedAppCacheManager().removeWalletInfo()
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
        val active_seed = "${account_name}active$password"
        val active_private_wif = OrgUtils.genBtsWifPrivateKey(active_seed.utf8String())
        val owner_seed = "${account_name}owner$password"
        val owner_private_wif = OrgUtils.genBtsWifPrivateKey(owner_seed.utf8String())
        val memo_seed = "${account_name}memo$password"
        val memo_private_wif = OrgUtils.genBtsWifPrivateKey(memo_seed.utf8String())
        val active_pubkey = OrgUtils.genBtsAddressFromWifPrivateKey(active_private_wif)!!
        val owner_pubkey = OrgUtils.genBtsAddressFromWifPrivateKey(owner_private_wif)!!
        val memo_pubkey = OrgUtils.genBtsAddressFromWifPrivateKey(memo_private_wif)!!

        //  保存到内存
        _private_keys_hash = JSONObject()
        _private_keys_hash.put(active_pubkey, active_private_wif)
        _private_keys_hash.put(owner_pubkey, owner_private_wif)
        _private_keys_hash.put(memo_pubkey, memo_private_wif)

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
     *  (public) 获取石墨烯私钥对象。
     */
    fun getGraphenePrivateKeyByPublicKey(wif_public_key: String): GraphenePrivateKey? {
        assert(!isLocked())
        if (_private_keys_hash.has(wif_public_key)) {
            return GraphenePrivateKey.fromWifPrivateKey(_private_keys_hash.getString(wif_public_key))
        }
        return null
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
    fun getSignKeys(raw_permission_json: JSONObject, assert_enough_permission: Boolean = true): JSONArray {
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
        if (assert_enough_permission) {
            assert(canAuthorizeThePermission(raw_permission_json))
        }
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
    fun signTransaction(sign_buffer: ByteArray, signKeys: JSONArray, extra_keys_hash: JSONObject? = null): JSONArray? {
        assert(signKeys.length() > 0)

        //  循环签名
        val result = JSONArray()
        for (pubkey in signKeys.forin<String>()) {
            //  获取WIF私钥
            var private_key_wif = _private_keys_hash.optString(pubkey!!)
            if (private_key_wif.isEmpty() && extra_keys_hash != null) {
                private_key_wif = extra_keys_hash.optString(pubkey)
            }
            //  未解锁或者私钥不存在 返回失败
            if (private_key_wif.isEmpty()) {
                return null
            }

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
     *  (public) 解密memo数据，失败返回nil。
     */
    fun decryptMemoObject(memo_object: JSONObject): String? {
        assert(!isLocked())
        val from = memo_object.getString("from")
        val to = memo_object.getString("to")
        val nonce = memo_object.getString("nonce")
        val message = memo_object.getString("message")

        //  1、获取私钥和公钥（from和to任意一方私钥即可，双方均可解密。）
        var pubkey: String? = null
        var prikey: String? = null
        val from_prikey_wif = _private_keys_hash.optString(from, null)
        val to_prikey_wif = _private_keys_hash.optString(to, null)
        if (from_prikey_wif != null) {
            prikey = from_prikey_wif
            pubkey = to
        } else if (to_prikey_wif != null) {
            prikey = to_prikey_wif
            pubkey = from
        } else {
            //  no any private key
            return null
        }

        val nativePtr = NativeInterface.sharedNativeInterface()

        //  获取私钥
        val memo_private_key32 = nativePtr.bts_gen_private_key_from_wif_privatekey(prikey.utf8String())
        if (memo_private_key32 == null) {
            return null
        }

        //  获取公钥
        val public_key = nativePtr.bts_gen_public_key_from_b58address(pubkey.utf8String(), ChainObjectManager.sharedChainObjectManager().grapheneAddressPrefix.utf8String())
        if (public_key == null) {
            return null
        }

        val plain_ptr = nativePtr.bts_aes256_decrypt_with_checksum(memo_private_key32, public_key, nonce.utf8String(), message.hexDecode())
        if (plain_ptr == null) {
            return null
        }

        return plain_ptr.utf8String()
    }

    /**
     * (public) 加密并生成 memo 信息结构体，失败返回 nil。
     */
    fun genMemoObject(memo: String, from_public: String, to_public: String, extra_keys_hash: JSONObject? = null): JSONObject? {
        assert(!isLocked())

        //  1、获取和 from_public 对应的备注私钥
        var from_public_private_key_wif = _private_keys_hash.optString(from_public, null)
        if (from_public_private_key_wif == null && extra_keys_hash != null) {
            from_public_private_key_wif = extra_keys_hash.optString(from_public, null)
        }
        if (from_public_private_key_wif == null) {
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
    fun genFullWalletData(ctx: Context, account_name_or_namelist: Any, private_wif_keys: JSONArray, wallet_password: String): ByteArray? {
        var account_name_list: JSONArray? = null
        if (account_name_or_namelist is String) {
            account_name_list = jsonArrayfrom(account_name_or_namelist)
        } else if (account_name_or_namelist is JSONArray) {
            account_name_list = account_name_or_namelist
        } else {
            assert(false)
        }
        val full_wallet_object = genFullWalletObject(ctx, account_name_list!!, private_wif_keys, wallet_password)
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
    fun genFullWalletObject(ctx: Context, account_name_list: JSONArray, private_wif_keys: JSONArray, wallet_password: String): JSONObject? {
        assert(account_name_list.length() > 0)

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

        //  part2
        val chain_id = ChainObjectManager.sharedChainObjectManager().grapheneChainID
        val linked_account_list = JSONArray()
        account_name_list.forEach<String> { name ->
            linked_account_list.put(jsonObjectfromKVS("chainId", chain_id, "name", name!!))
        }

        //  part3
        val wallet = JSONObject()
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
        val final_object = JSONObject()
        final_object.put("linked_accounts", linked_account_list)
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








