package bitshares

import java.math.BigDecimal

//  【系统通知】网络重连成功后发送
const val kBtsWebsocketReconnectSuccess = "kBtsWebsocketReconnectSuccess"

//  BTS 对象本地缓存过期时间
const val kBTSObjectCacheExpireTime = 86400

//  5星好评地址 TODO
const val kApp5StarURL = "https://play.google.com/store/apps/details?id=org.bitshares.app"

//  UI - 部分参数配置
const val kUITableViewLeftEdge = 12.0f       //  左边距

//  配置：[默认值]
const val uDownloadManagerThreadNumber = 8

//  UI - 用户资产 默认显示数量（多余的资产不显示）
const val kAppUserAssetDefaultShowNum = 10

//  [by app] 导入的钱包bin文件缓存目录 /AppCache/app/wbin/#{binfilename}
const val kAppWalletBinFileDir = "wbin"

//  [by app] WebServer导入文件存储目录（导入钱包先上传到该目录，钱包密码验证通过后移动到 wbin 目录。）/AppCache/app/wsimport/#{filename}
const val kAppWebServerImportDir = "wsimport"

//  软件：本地文件最终路径：
//  1、/AppCache/ver/#{curr_version}_filename
//  2、/AppCache/app/filename

//  软件：本地写入文件根目录
const val kAppLocalFileNameBase = "AppCache"
//  软件：本地当前版本依赖文件写入目录
const val kAppLocalFileNameByVerStorage = "ver"
//  软件：本地app依赖文件写入目录（跨所有版本）
const val kAppLocalFileNameByAppStorage = "app"

//  by app
const val kAppCacheNameMemoryInfosByApp = "memory_v1.json"
const val kAppCacheNameWalletInfoByApp = "wallet_v1.json"
const val kAppCacheNameObjectCacheByApp = "object_v1.json"
const val kAppCacheNameFavAccountsByApp = "favaccounts_v1.json"
const val kAppCacheNameFavMarketsByApp = "myfavmarkets_v1.json"
const val kAppCacheNameUserSettingByApp = "usersetting_v1.json"

//  设置界面存储数据的 KEY 值
const val kSettingKey_EstimateAssetSymbol = "kEstimateAssetSymbol"  //  计价单位符号 CNY、USD等
const val kSettingKey_KLineIndexInfo = "kKLineIndexInfo_v2"         //  K线指标参数信息    REMARK：如果新增指标需要更新下参数版本
const val kSettingKey_EnableHorTradeUI = "kEnableHorTradeUI_v1"     //  启用横版交易界面
const val kSettingKey_ApiNode = "kApiNode_v1"                       //  API节点设置信息
const val kSettingKey_ApiNode_Current = "current_node"              //  API节点设置信息 - 子KEY（当前选择节点，为空则随机选择）
const val kSettingKey_ApiNode_CustomList = "custom_list"            //  API节点设置信息 - 子KEY（自定义列表）

/**
 * 网络类型
 */
const val kNETWORK_CLASS_UNKNOWN = 0
const val kNETWORK_WIFI = 1
const val kNETWORK_CLASS_2_G = 2
const val kNETWORK_CLASS_3_G = 3
const val kNETWORK_CLASS_4_G = 4


/**
 * K线相关参数
 */
//  K线图中价格区间、日期区间、最低最高价格、成交量、MA信息等小主要文字字号
val kBTS_KLINE_PRICE_VOL_FONTSIZE = 8.0f.dp

//  K线背景边框行列数
const val kBTS_KLINE_COL_NUM = 4
const val kBTS_KLINE_ROW_NUM = 5

//  K线MA等指标区域高度（相对于ROW的比例，比如行高80，则MA高度20。）
const val kBTS_KLINE_MA_HEIGHT = 0.25f

//  K线蜡烛图实体默认宽度、最小宽度、最大宽度（影响缩放）
val kBTS_KLINE_CANDLE_WIDTH = 3.dp
const val kBTS_KLINE_CANDLE_WIDTH_MIN = 0
val kBTS_KLINE_CANDLE_WIDTH_MAX = 9.dp

//  K线蜡烛图影线宽度
val kBTS_KLINE_SHADOW_WIDTH = 1.dp

//  K线蜡烛图之间的间隔宽度
val kBTS_KLINE_INTERVAL = 2.dp

//  K线最多显示的蜡烛图数量（一直往回滑动）    TODO:fowallet bts一次最多返回200，更多记录需要多次请求。
const val kBTS_KLINE_MAX_SHOW_CANDLE_NUM = 200

//  K线中指向最低价格、最高价格的短横线长度
val kBTS_KLINE_HL_PRICE_SHORT_LINE_LENGTH = 12.dp

//  BigDecimal大数计算不指定精度时默认采用的精度。
val kBigDecimalDefaultMaxPrecision = 16

//  BigDecimal大数计算时默认的round模式
val kBigDecimalDefaultRoundingMode = BigDecimal.ROUND_HALF_UP

//  startActivity传递参数时的ID
const val BTSPP_START_ACTIVITY_PARAM_ID = "btspp_start_activity_param_id"

/**
 *  钱包中存在的私钥对指定权限状态枚举。
 */
enum class EAccountPermissionStatus(val value: Int) {
    EAPS_NO_PERMISSION(0),      //  无任何权限
    EAPS_PARTIAL_PERMISSION(1), //  有部分权限
    EAPS_ENOUGH_PERMISSION(2),  //  有足够的权限
    EAPS_FULL_PERMISSION(3)     //  有所有权限
}

/**
 *  导入钱包结果
 */
enum class EImportToWalletStatus(val value: Int) {
    eitws_ok(0),                    //  导入成功
    eitws_no_permission(1),         //  无任何权限
    eitws_partial_permission(2)     //  有部分权限
}
