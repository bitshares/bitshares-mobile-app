//
//  OrgUtils.h
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import <Foundation/Foundation.h>
#import "WsPromise.h"

typedef void (^NormalCallback)(NSString* err, id data);
typedef void (^YklUserCallback)(id data);

@class VCBase;

@interface OrgUtils : NSObject

/**
 *  日志统计
 */
+ (void)logEvents:(NSString*)eventname params:(NSDictionary*)params;

/**
 *  示石墨烯网络错误信息（部分错误特殊处理）
 */
+ (void)showGrapheneError:(id)error;

/**
 *  [权限] - 请求访问相机
 */
+ (WsPromise*)authorizationForCamera;

/**
 *  在系统浏览器中打开指定网页。
 */
+ (void)safariOpenURL:(NSString*)url;

/**
 *  判断账号权限是否属于多签权限。权限json格式参考：T_authority
 *  REMARK：判断规则，只要权限主题超过1个即视为多签。即：account_auths、address_auths、key_auths数量之和大于1.
 */
+ (BOOL)isMutilSignPermission:(NSDictionary*)raw_permission_json;

/**
 *  辅助 - 根据字符串获取 NSDecimalNumber 对象，如果字符串以小数点结尾，则默认添加0。
 */
+ (NSDecimalNumber*)auxGetStringDecimalNumberValue:(NSString*)str;

/**
 *  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
 */
+ (void)correctTextFieldDecimalSeparatorDisplayStyle:(UITextField*)textField;

/**
 *  对于价格 or 数量类型的输入，判断是否是有效输入等。
 *  规则：
 *  1、不能有多个小数点
 *  2、不能以小数点开头
 *  3、不能包含字母等非数字输入
 *  4、小数位数不能超过 precision
 */
+ (BOOL)isValidAmountOrPriceInput:(NSString*)origin_string range:(NSRange)range new_string:(NSString*)new_string precision:(NSInteger)precision;

/**
 *  是否是BTS终身会员判断
 */
+ (BOOL)isBitsharesVIP:(NSString*)membership_expiration_date_string;

/**
 *  (public) 帐号格式有效性判断
 */
+ (BOOL)isValidBitsharesAccountName:(NSString*)name;

/**
 *  (public) 帐号模式：帐号密码格式是否正确
 */
+ (BOOL)isValidBitsharesAccountPassword:(NSString*)password;

/**
 *  (public) 钱包模式：钱包密码格式是否正确
 */
+ (BOOL)isValidBitsharesWalletPassword:(NSString*)password;

/**
 *  (public) 原像格式是否正确
 *  格式：20位以上，包含大写字母和数字。
 */
+ (BOOL)isValidHTCLPreimageFormat:(NSString*)preimage;

/**
 *  是否是有效的16进制字符串检测。
 */
+ (BOOL)isValidHexString:(NSString*)hexstring;

/**
 *  解析 BTS 网络时间字符串，返回 1970 到现在的秒数。格式：2018-06-04T13:03:57。
 */
+ (NSTimeInterval)parseBitsharesTimeString:(NSString*)time;

/**
 *  格式化时间戳为 BTS 网络时间字符串格式。格式：2018-06-04T13:03:57。
 */
+ (NSString*)formatBitsharesTimeString:(NSTimeInterval)time_secs;

/**
 *  格式化：交易历史时间显示格式  24小时内，直接显示时分秒，24小时以外了则显示 x天前。REMARK：以当前时区格式化，BTS默认时间是UTC。北京时间当前时区会+8。
 */
+ (NSString*)fmtTradeHistoryTimeShowString:(NSString*)time;

/**
 *  格式化：限价单过期日期显示格式。REMARK：以当前时区格式化，BTS默认时间是UTC。北京时间当前时区会+8。
 */
+ (NSString*)fmtLimitOrderTimeShowString:(NSString*)time;

/**
 *  格式化：帐号历史日期显示格式。REMARK：以当前时区格式化，BTS默认时间是UTC。北京时间当前时区会+8。
 */
+ (NSString*)fmtAccountHistoryTimeShowString:(NSString*)time;

/**
 *  格式化：喂价发布日期。
 */
+ (NSString*)fmtFeedPublishDateString:(NSString*)time;

/**
 *  格式化：解冻周期。
 */
+ (NSString*)fmtVestingPeriodDateString:(NSUInteger)seconds;

/**
 *  格式化：交易OP编码转换为字符串名字。
 */
+ (NSString*)opcode2opname:(NSUInteger)opcode;

/**
 *  (public) 根据【失去】和【得到】的资产信息计算订单方向行为（买卖、价格、数量等）
 *  priority_hash - 优先级Hash（可选）
 */
+ (NSDictionary*)calcOrderDirectionInfos:(NSDictionary*)priority_hash pay_asset_info:(id)pay_asset_info receive_asset_info:(id)receive_asset_info;

/**
 *  获取 worker 类型。0:refund 1:vesting 2:burn
 */
+ (NSInteger)getWorkerType:(NSDictionary*)worker_json_object;

/**
 *  从操作的结果结构体中提取新对象ID。
 */
+ (NSString*)extractNewObjectIDFromOperationResult:(id)operation_result;

/**
 *  从广播交易结果获取新生成的对象ID号（比如新的订单号、新HTLC号等）
 *  考虑到数据结构可能变更，加各种safe判断。
 *  REMARK：仅考虑一个 op 的情况，如果一个交易包含多个 op 则不支持。
 */
+ (NSString*)extractNewObjectID:(id)transaction_confirmation_list;

/**
 *  提取OPDATA中所有的石墨烯ID信息。
 */
+ (void)extractObjectID:(NSUInteger)opcode opdata:(id)opdata container:(NSMutableDictionary*)container;

/**
 *  转换OP数据为UI显示数据。
 */
+ (NSDictionary*)processOpdata2UiData:(NSUInteger)opcode opdata:(id)opdata opresult:(id)opresult isproposal:(BOOL)isproposal;

/**
 *  计算资产真实价格
 */
+ (double)calcAssetRealPrice:(id)amount precision:(NSInteger)precision;

/**
 *  根据 price_item 计算价格。REMARK：price_item 包含 base 和 quote 对象，base 和 quote 包含 asset_id 和 amount 字段。
 */
+ (NSDecimalNumber*)calcPriceFromPriceObject:(id)price_item
                                     base_id:(NSString*)base_id
                              base_precision:(NSInteger)base_precision
                             quote_precision:(NSInteger)quote_precision
                                      invert:(BOOL)invert
                                roundingMode:(NSRoundingMode)roundingMode
                        set_divide_precision:(BOOL)set_divide_precision;

/**
 *  (public) 计算在爆仓时最少需要卖出的资产数量，如果没设置目标抵押率则全部卖出。如果有设置则根据目标抵押率计算。
 */
+ (NSDecimalNumber*)calcSettlementSellNumbers:(id)call_order
                               debt_precision:(NSInteger)debt_precision
                         collateral_precision:(NSInteger)collateral_precision
                                   feed_price:(NSDecimalNumber*)feed_price
                                   call_price:(NSDecimalNumber*)call_price
                                          mcr:(NSDecimalNumber*)mcr
                                         mssr:(NSDecimalNumber*)mssr;

/**
 *  (public) 计算强平触发价格。
 *  call_price = (debt × MCR) ÷ collateral
 */
+ (NSDecimalNumber*)calcSettlementTriggerPrice:(id)debt_amount
                                    collateral:(id)collateral_amount
                                debt_precision:(NSInteger)debt_precision
                          collateral_precision:(NSInteger)collateral_precision
                                         n_mcr:(id)n_mcr
                                       reverse:(BOOL)reverse
                                  ceil_handler:(NSDecimalNumberHandler*)ceil_handler
                          set_divide_precision:(BOOL)set_divide_precision;

/**
 *  (public) 合并普通盘口信息和爆仓单信息。
 */
+ (NSDictionary*)mergeOrderBook:(NSDictionary*)normal_order_book settlement_data:(NSDictionary*)settlement_data;

/**
 *  (public) 格式化ASSET_JSON对象为价格字符串，例：2323.32BTS
 */
+ (NSString*)formatAssetAmountItem:(id)asset_json;

/**
 *  格式化资产显示字符串，保留指定有效精度。带逗号分隔。
 */
+ (NSString*)formatAssetString:(id)amount precision:(NSInteger)precision;
+ (NSString*)formatAssetString:(id)amount asset:(id)asset;

/**
 *  格式化资产数量显示，如果数量太大会按照 xxK xxM形式进行显示。
 */
+ (NSString*)formatAmountString:(id)amount asset:(id)asset;

/**
 *  生成资产数量多 NSDecimalNumber 对象。
 */
+ (NSDecimalNumber*)genAssetAmountDecimalNumber:(id)amount asset:(id)asset;

/**
 *  格式化浮点数，保留指定有效精度，可指定是否带组分割符。
 */
+ (NSString*)formatFloatValue:(double)value precision:(NSInteger)precision usesGroupingSeparator:(BOOL)usesGroupingSeparator;
+ (NSString*)formatFloatValue:(double)value precision:(NSInteger)precision;
+ (NSString*)formatFloatValue:(NSDecimalNumber*)value usesGroupingSeparator:(BOOL)usesGroupingSeparator;
+ (NSString*)formatFloatValue:(NSDecimalNumber*)value;

/**
 *  根据 get_full_accounts 接口返回的所有用户信息计算用户所有资产信息、挂单信息、抵押信息、债务信息等。
 *  返回值 {validBalancesHash, limitValuesHash, callValuesHash, debtValuesHash}
 */
+ (NSDictionary*)calcUserAssetDetailInfos:(NSDictionary*)full_user_data;

/**
 *  获取设备IP地址
 */
+ (NSString*)getIPAddress;

/**
 *  16进制解码
 */
+ (NSData*)hexDecode:(NSString*)hex_string;

/**
 *  根据私钥种子字符串生成 WIF 格式私钥。
 */
+ (NSString*)genBtsWifPrivateKey:(NSString*)seed;

+ (NSString*)genBtsWifPrivateKey:(const unsigned char*)seed size:(size_t)seed_size;

/**
 *  根据32字节原始私钥生成 WIF 格式私钥
 */
+ (NSString*)genBtsWifPrivateKeyByPrivateKey32:(NSData*)private_key32;

/**
 *  根据私钥种子字符串生成 BTS 地址字符串。
 */
+ (NSString*)genBtsAddressFromPrivateKeySeed:(NSString*)seed;

/**
 *  根据 WIF格式私钥 字符串生成 BTS 地址字符串。
 */
+ (NSString*)genBtsAddressFromWifPrivateKey:(NSString*)wif_private_key;

+ (BOOL)writeFileAny:(id)data withFullPath:(NSString*)fullpath withDirPath:(NSString*)dirpath;

+ (BOOL)writeFile:(NSData*)data withFullPath:(NSString*)fullpath withDirPath:(NSString*)dirpath;
+ (BOOL)writeFileArray:(NSArray*)data withFullPath:(NSString*)fullpath withDirPath:(NSString*)dirpath;

+ (BOOL)deleteFile:(NSString*)fullpath;

+ (NSString*)makePathFromApplicationSupportDirectory:(NSString*)path;

/**
 *  获取 Document 目录，该目录文件在设置共享标记之后可以被 iTunes 读取和写入。REMARK：钱包文件应该存储在该目录（重要）。不能是子目录。
 */
+(NSString*)getDocumentDirectory;

/**
 *  解压zip文件到指定目录
 */
+(BOOL)extractZipFile:(NSString*)zipfilename dstpath:(NSString*)dstpath;

/**
 *  重命名文件（目标文件存在则会覆盖）
 */
+(BOOL)renameFile:(NSString*)srcpath dst:(NSString*)dstpath;

/**
 *  直接读取缓存数据
 */
+(NSString*)loaddataByVerStorage:(NSString*)filename;
+(NSString*)loaddataByAppStorage:(NSString*)filename;

/**
 *  写入数据
 */
+(BOOL)saveDataToDataCache:(NSString*)filename data:(NSString*)data base64decode:(BOOL)base64decode;

/**
 *  获取版本依赖文件的完整文件名（路径）
 */
+(NSString*)makeFullPathByVerStorage:(NSString*)filename;

/**
 *  获取app依赖文件的完整文件名（路径）
 */
+(NSString*)makeFullPathByAppStorage:(NSString*)filename;

/**
 *  获取广告图片所在缓存的完整路径
 */
+(NSString*)makeFullPathByAdStorage:(NSString *)filename;

/**
 *  获取钱包bin文件所在目录。
 */
+(NSString*)getAppDirWalletBin;

/**
 *  获取webserver导入目录
 */
+(NSString*)getAppDirWebServerImport;

/**
 *  (public) 异步Promise模型 HTTP GET 方法。
 */
+(WsPromise*)asyncFetchUrl:(NSString*)pURL args:(NSDictionary*)args;
+(void)asyncFetchUrl:(NSString*)pURL completionBlock:(void (^)(NSData*))completion;
+(void)asyncDownload:(NSString*)pURL verifyMD5:(NSString*)pMD5 fullpath:(NSString*)fullpath completionBlock:(void (^)(BOOL))completion;
+(void)asyncFetchJson:(NSString*)pURL timeout:(NSTimeInterval)seconds completionBlock:(void (^)(id json))completion;
+(WsPromise*)asyncPostUrl:(NSString*)pURL args:(NSDictionary*)kvhash;
+(WsPromise*)asyncPostUrl_jsonBody:(NSString*)pURL args:(NSDictionary*)json;

+(NSString*)md5:(NSString*)utf8string;
+(NSString*)calcFileMD5:(NSString*)pFilePath;
+(NSString*)calcNSDataMD5:(NSData*)pData;

+(void)showMessage:(NSString*)pMessage;
+(void)showMessage:(NSString*)pMessage withTitle:(NSString*)pTitle;
+(void)showMessageUseHud:(NSString*)pMessage time:(NSInteger)sec parent:(UIView*)pView completionBlock:(void (^)())completion;

+(NSInteger)compareVersion:(NSString*)pVer1 other:(NSString*)pVer2;

//+(NSDictionary*)formatDate:(NSInteger)offsetdays;
+(NSString*)getDateLocaleString: (NSDate*)date withYear:(BOOL)withYear;
+(NSString*)getDateLocaleString: (NSString *)dateString fmt:(NSString*)fmt withYear:(BOOL)withYear;
+(NSString*)getDateTimeLocaleString:(NSDate*)date withTime:(BOOL)withTime;
+(NSString*)getStringFromDate:(NSDate*)date fmt:(NSString*)fmt;
+(NSString*)getDateTimeLocaleString:(NSDate*)date;
//+(NSDate*)getDateFrom: (NSString*)dateString fmt:(NSString*)fmt;
//+(NSString*)calcWeekStr:(NSString*)datestr fmt:(NSString*)fmt;
//+(NSString*)calcWeekStrFromDate:(NSDate*)date;
//+(NSString*)calcYearMonthDayNow;

//+ (NSInteger)getCurrentYearNumber;
+ (NSInteger)getDaysOfMonth:(NSInteger)year month:(NSInteger)month;

+ (NSDate *)dateFromString:(NSString *)dateString;
+ (NSInteger)daysBetweenDate:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime;
/**
 *  从格式化字符串获取 NSDate 对象。
 */
+ (NSDate*)getDateFromString:(NSString*)datestring fmt:(NSString*)fmt;

/**
 *  深度克隆对象，克隆的对象是mutable的。
 */
+ (id)deepClone:(id)obj;

+ (float)getHeightForText:(NSString*)text font:(UIFont*)font width:(float)width;
// 根据文本内容自动调整高度
+ (void)adjustHeightForLabel:(UILabel*)label;

//  计算字符串多字结束（一个英文字符占1个字节，其他非英文字符占2个字节。）
+ (NSUInteger)calcGB2312ByteLength:(NSString*)str;

/**
 *  把$1 $2之类的占位符替换为 %@
 */
+ (NSString*)replacePlaceholder:(NSString*)src;


+ (void)printView:(UIView*)view level:(NSInteger)level;

/**
 *  显示 toast 信息，支持设置时间，默认 2s。
 */
+ (void)makeToast:(NSString*)message;
+ (void)makeToast:(NSString *)message position:(id)position;

+ (id)safeGet:(NSDictionary*)dict key:(NSString*)key defaultValue:(NSObject*)defaultValue;
+ (id)safeGet:(NSDictionary*)dict key:(NSString*)key;
@end
