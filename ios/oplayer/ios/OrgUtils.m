//
//  OrgUtils.m
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import "OrgUtils.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import "MBProgressHUD.h"
#import "AppCommon.h"
#import "NativeAppDelegate.h"
#import "UIAlertViewManager.h"
#import "AppCacheManager.h"
#import "SettingManager.h"
#import "VCBase.h"

#import "Crashlytics/Crashlytics.h"
#import "unzip.h"
#include "zlib.h"

#include "UIView+Toast.h"

#import "BitsharesClientManager.h"

#import <ifaddrs.h>
#import <arpa/inet.h>

#import <AVFoundation/AVFoundation.h>

#import <Flurry/Flurry.h>

#define CHUNK_SIZE 1024

/**
 *  加密部分小数据（如密码等）
 */
NSString* gSmallDataEncode(NSString* str, NSString* key)
{
    const char* iv = [key UTF8String];
    
    char outbuf[1024] = {0,};
    size_t outsize = 0;
    
    //  加密
    NSData* data = [str dataUsingEncoding:NSUTF8StringEncoding];
    CCCryptorStatus ret = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding, [key UTF8String], kCCKeySizeAES128, iv, [data bytes], [data length], outbuf, 1024, &outsize);
    if (ret != kCCSuccess){
        return nil;
    }
    
    //  base64 编码
    NSData* d1 = [[NSData alloc] initWithBytes:outbuf length:outsize];
    NSString* base64str = [d1 base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
//    [d1 release];
    
    return base64str;
}

/**
 *  解密部分小数据（如密码等）
 */
NSString* gSmallDataDecode(NSString* str, NSString* key)
{
    const char* iv = [key UTF8String];
    
    char outbuf[1024] = {0,};
    size_t outsize = 0;
    
    //  base64 解码
    NSData* data = [[NSData alloc] initWithBase64EncodedString:str options:0];
    
    //  解密
    CCCryptorStatus ret = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding, [key UTF8String], kCCKeySizeAES128, iv, [data bytes], [data length], outbuf, 1024, &outsize);
    if (ret != kCCSuccess){
        return nil;
    }
    
    return [[NSString alloc] initWithBytes:outbuf length:outsize encoding:NSUTF8StringEncoding];
}

@implementation OrgUtils

/**
 *  日志统计
 */
+ (void)logEvents:(NSString*)eventname params:(NSDictionary*)params
{
    [Answers logCustomEventWithName:eventname customAttributes:params];
    [Flurry logEvent:eventname withParameters:params];
}

/**
 *  示石墨烯网络错误信息（部分错误特殊处理）
 */
+ (void)showGrapheneError:(id)error
{
    if (error && [error isKindOfClass:[WsPromiseException class]]){
        WsPromiseException* excp = (WsPromiseException*)error;
        if (excp.userInfo){
            NSString* message = [excp.userInfo objectForKey:@"message"];
            if (message){
                //  REMARK：部分错误特化显示
                if ([message rangeOfString:@"no such account"].location != NSNotFound){
                    [self makeToast:NSLocalizedString(@"kGPErrorAccountNotExist", @"账号不存在。")];
                    return;
                }
                if ([message rangeOfString:@"Insufficient Balance"].location != NSNotFound){
                    [self makeToast:NSLocalizedString(@"kGPErrorInsufficientBalance", @"手续费不足。")];
                    return;
                }
                NSString* lowermsg = [message lowercaseString];
                if ([lowermsg rangeOfString:@"preimage size"].location != NSNotFound ||
                    [lowermsg rangeOfString:@"provided preimage"].location != NSNotFound){
                    [self makeToast:NSLocalizedString(@"kGPErrorRedeemInvalidPreimage", @"原像不正确。")];
                    return;
                }
                //  TODO:fowallet 提案等手续费不足等情况显示
            }
        }
    }
    [self makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
}

/**
 *  [权限] - 请求访问相机
 */
+ (WsPromise*)authorizationForCamera
{
    //  TODO：fowallet 多语言
    WsPromise* promise = [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (device) {
            AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
            switch (status) {
                case AVAuthorizationStatusNotDetermined: {
                    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                        if (granted) {
                            resolve(@"ok01");
                        } else {
                            reject(@"拒绝访问相机。");
                        }
                    }];
                    break;
                }
                case AVAuthorizationStatusAuthorized: {
                    resolve(@"ok02");
                    break;
                }
                case AVAuthorizationStatusDenied: {
                    reject(@"请去前往【设置>隐私>相机>BTS++】打开访问开关。");
                    break;
                }
                case AVAuthorizationStatusRestricted: {
                    reject(@"因为系统原因, 无法访问相册。");
                    break;
                }
                default:
                    break;
            }
        }else{
            reject(@"未检测到您的摄像头。");
        }
    }];
    return promise;
}

/**
 *  在系统浏览器中打开指定网页。
 */
+ (void)safariOpenURL:(NSString*)url
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

/**
 *  判断账号权限是否属于多签权限。权限json格式参考：T_authority
 *  REMARK：判断规则，只要权限主题超过1个即视为多签。即：account_auths、address_auths、key_auths数量之和大于1.
 */
+ (BOOL)isMutilSignPermission:(NSDictionary*)raw_permission_json
{
    assert(raw_permission_json);
    id account_auths = [raw_permission_json objectForKey:@"account_auths"];
    id address_auths = [raw_permission_json objectForKey:@"address_auths"];
    id key_auths = [raw_permission_json objectForKey:@"key_auths"];
    return [account_auths count] + [address_auths count] + [key_auths count] > 1;
}

/**
 *  辅助 - 根据字符串获取 NSDecimalNumber 对象，如果字符串以小数点结尾，则默认添加0。
 */
+ (NSDecimalNumber*)auxGetStringDecimalNumberValue:(NSString*)str
{
    if (!str || [str isEqualToString:@""]){
        return [NSDecimalNumber zero];
    }
    
    LangManager* langMgr = [LangManager sharedLangManager];
    NSString* decimalSeparator = langMgr.appDecimalSeparator;
    NSString* groupingSeparator = langMgr.appGroupingSeparator;
    
    //  去除组分割符
    str = [[str componentsSeparatedByString:groupingSeparator] componentsJoinedByString:@""];
    
    //  以小数点结尾则在默认添加0。
    if ([str rangeOfString:decimalSeparator].location == [str length] - 1){
        str = [NSString stringWithFormat:@"%@0", str];
    }
    
    //  替换小数点
    if (![decimalSeparator isEqualToString:@"."]){
        str = [str stringByReplacingOccurrencesOfString:decimalSeparator withString:@"."];
    }
    
    return [NSDecimalNumber decimalNumberWithString:str];
}

/**
 *  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
 */
+ (void)correctTextFieldDecimalSeparatorDisplayStyle:(UITextField*)textField
{
    LangManager* langMgr = [LangManager sharedLangManager];
    NSString* imeDecimalSeparator = [langMgr queryDecimalSeparatorByLannguage:[UIApplication sharedApplication].textInputMode.primaryLanguage];
    NSString* appDecimalSeparator = langMgr.appDecimalSeparator;
    if (![imeDecimalSeparator isEqualToString:appDecimalSeparator]){
        textField.text = [textField.text stringByReplacingOccurrencesOfString:imeDecimalSeparator withString:appDecimalSeparator];
    }
}

/**
 *  对于价格 or 数量类型的输入，判断是否是有效输入等。
 *  规则：
 *  1、不能有多个小数点
 *  2、不能以小数点开头
 *  3、不能包含字母等非数字输入
 *  4、小数位数不能超过 precision
 */
+ (BOOL)isValidAmountOrPriceInput:(NSString*)origin_string range:(NSRange)range new_string:(NSString*)new_string precision:(NSInteger)precision
{
    //  获取小数点符号
    LangManager* langMgr = [LangManager sharedLangManager];
    
    NSString* imeDecimalSeparator = [langMgr queryDecimalSeparatorByLannguage:[UIApplication sharedApplication].textInputMode.primaryLanguage];
    NSString* appDecimalSeparator = langMgr.appDecimalSeparator;
    
    unichar appDecimalSeparatorUnichar = [appDecimalSeparator characterAtIndex:0];
    unichar imeDecimalSeparatorUnichar = [imeDecimalSeparator characterAtIndex:0];
    
    //  REMARK：限制输入 第一个字母不能是小数点，并且总共只能有1个小数点。
    BOOL isHaveDian = NO;
    if (origin_string && [origin_string rangeOfString:appDecimalSeparator].location != NSNotFound){
        isHaveDian = YES;
    }
    if (new_string && [new_string length] > 0){
        //  当前输入的字符
        unichar single = [new_string characterAtIndex:0];
        //  数据格式正确
        if ((single >= '0' && single <= '9') || single == appDecimalSeparatorUnichar || single == imeDecimalSeparatorUnichar){
            //  首字母
            if ([origin_string length] == 0){
                //  REMARK：不能小数点开头
                if (single == appDecimalSeparatorUnichar || single == imeDecimalSeparatorUnichar){
                    return NO;
                }
                return YES;
            }
            //  非首字母-小数点
            if (single == appDecimalSeparatorUnichar || single == imeDecimalSeparatorUnichar){
                //  REMARK：不能包含多个小数点
                if (isHaveDian)
                {
                    return NO;
                }
                return YES;
            }else{
                if (isHaveDian){
                    NSString* dst_string = new_string;
                    if (appDecimalSeparatorUnichar != imeDecimalSeparatorUnichar){
                        dst_string = [new_string stringByReplacingOccurrencesOfString:imeDecimalSeparator withString:appDecimalSeparator];
                    }
                    NSString* test_string = [origin_string stringByReplacingCharactersInRange:range withString:dst_string];
                    NSRange new_range = [test_string rangeOfString:appDecimalSeparator];
                    if (new_range.location != NSNotFound){
                        int fraction_digits = (int)test_string.length - ((int)new_range.location + 1);
                        //  REMARK：限制小数位数
                        return fraction_digits <= precision;
                    }else{
                        //  没有小数点了（被替换掉了），则不限制。
                        return YES;
                    }
                }else{
                    //  当前不存在小数点
                    return YES;
                }
            }
        }else{
            //  REMARK：不能包含字母等
            return NO;
        }
    }else{
        return YES;
    }
}

/**
 *  是否是BTS终身会员判断
 */
+ (BOOL)isBitsharesVIP:(NSString*)membership_expiration_date_string
{
    //  帐号信息可能缺失。
    if (!membership_expiration_date_string){
        return NO;
    }
    //  会员过期日期为 -1 则为终身会员。
    NSTimeInterval expire_ts = [self parseBitsharesTimeString:membership_expiration_date_string];
    return expire_ts < 0;
}

/**
 *  (public) 帐号格式有效性判断　TODO:fowallet 格式细节
 */
+ (BOOL)isValidBitsharesAccountName:(NSString*)name
{
    if (!name || [name length] <= 0){
        return NO;
    }
    if ([name length] > 32){    //  TODO:fowallet cfg
        return NO;
    }
    
    id parts_ary = [name componentsSeparatedByString:@"."];
    if ([parts_ary count] >= 2){
        for (NSString* part in parts_ary) {
            //  每个分段必须3位以上
            if (part.length < 3){
                return NO;
            }
            
            NSString* part_regular = @"\\A[a-z]+(?:[a-z0-9\\-\\.])*[a-z0-9]\\z";
            NSPredicate* part_regular_pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", part_regular];
            if (![part_regular_pre evaluateWithObject:part]){
                return NO;
            }
        }
    }
    
    NSString* account_name_regular = @"\\A[a-z]+(?:[a-z0-9\\-\\.])*[a-z0-9]\\z";
    NSPredicate* account_name_pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", account_name_regular];
    if ([account_name_pre evaluateWithObject:name]){
        return YES;
    }
    return NO;;
}
/**
 *  (public) 帐号模式：帐号密码格式是否正确　TODO:fowallet 格式细节
 *  格式：12位以上，包含大小写和数字。
 */
+ (BOOL)isValidBitsharesAccountPassword:(NSString*)password
{
    if (!password){
        return NO;
    }
    if ([password length] < 12){//TODO:fowallet cfg
        return NO;
    }
    //  大写、小写、数字检测
    NSArray* regular_list = @[@".*[A-Z]+.*", @".*[a-z]+.*", @".*[0-9]+.*"];
    for (id regular in regular_list) {
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regular];
        if (![pre evaluateWithObject:password]){
            return NO;
        }
    }
    return YES;
}
/**
 *  (public) 钱包模式：钱包密码格式是否正确 TODO:fowallet 格式细节
 *  格式：8位以上，包含大小写和数字。
 */
+ (BOOL)isValidBitsharesWalletPassword:(NSString*)password
{
    if (!password){
        return NO;
    }
    if ([password length] < 8){//TODO:fowallet cfg
        return NO;
    }
    //  大写、小写、数字检测
    NSArray* regular_list = @[@".*[A-Z]+.*", @".*[a-z]+.*", @".*[0-9]+.*"];
    for (id regular in regular_list) {
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regular];
        if (![pre evaluateWithObject:password]){
            return NO;
        }
    }
    return YES;
}

/**
 *  (public) 原像格式是否正确　TODO:fowallet 格式细节
 *  格式：20位以上，包含大写字母和数字。
 */
+ (BOOL)isValidHTCLPreimageFormat:(NSString*)preimage
{
    if (!preimage){
        return NO;
    }
    if ([preimage length] < 20){//TODO:fowallet cfg
        return NO;
    }
    //  大写、数字检测
    NSArray* regular_list = @[@".*[A-Z]+.*", @".*[0-9]+.*"];
    for (id regular in regular_list) {
        NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regular];
        if (![pre evaluateWithObject:preimage]){
            return NO;
        }
    }
    return YES;
}

/**
 *  是否是有效的16进制字符串检测。
 */
+ (BOOL)isValidHexString:(NSString*)hexstring
{
    if (!hexstring){
        return NO;
    }
    if (([hexstring length] % 2) != 0){
        return NO;
    }
    //  A-F、a-f、0-9 组成
    NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^[A-Fa-f0-9]+$"];
    if (![pre evaluateWithObject:hexstring]){
        return NO;
    }
    return YES;
}

/**
 *  解析 BTS 网络时间字符串，返回 1970 到现在的秒数。格式：2018-06-04T13:03:57。
 */
+ (NSTimeInterval)parseBitsharesTimeString:(NSString*)time
{
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    //  REMARK：格式化字符串已经有Z结尾表示时区了，这里可以不用设置。
    [dateFormat setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    //  REMARK：时间串后面添加Z结尾。
    NSString* z_end_regular = @".*Z$";
    NSPredicate* z_end_pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", z_end_regular];
    if (![z_end_pre evaluateWithObject:time]){
        time = [NSString stringWithFormat:@"%@Z", time];
    }
    NSDate* date_blockchain = [dateFormat dateFromString:time];
    return ceil([date_blockchain timeIntervalSince1970]);
}

/**
 *  格式化时间戳为 BTS 网络时间字符串格式。格式：2018-06-04T13:03:57。
 */
+ (NSString*)formatBitsharesTimeString:(NSTimeInterval)time_secs
{
    //  REMARM：日期格式化为 1970-01-01T00:00:00 格式
    NSDate* d = [NSDate dateWithTimeIntervalSince1970:time_secs];
    
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    [dateFormat setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];  //  REMARK：格式化字符串已经有Z结尾表示时区了，这里可以不用设置。
    NSString* ds = [dateFormat stringFromDate:d];
    
    return ds;
}

/**
 *  格式化：交易历史时间显示格式  24小时内，直接显示时分秒，24小时以外了则显示 x天前。REMARK：以当前时区格式化，BTS默认时间是UTC。北京时间当前时区会+8。
 */
+ (NSString*)fmtTradeHistoryTimeShowString:(NSString*)time
{
    NSTimeInterval ts = [self parseBitsharesTimeString:time];
    
    NSDate* now = [NSDate date];
    NSTimeInterval now_ts = [now timeIntervalSince1970];
    
    NSInteger diff_ts = (NSInteger)(now_ts - ts);
    if (diff_ts < 86400){
        NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"HH:mm:ss"];
        return [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970:ts]];
    }else{
        int day = (int)(diff_ts / 86400);
        return [NSString stringWithFormat:NSLocalizedString(@"kLabelTradeHisNdayAgo", @"%d天前"), day];
    }
}

/**
 *  格式化：限价单过期日期显示格式。REMARK：以当前时区格式化，BTS默认时间是UTC。北京时间当前时区会+8。
 */
+ (NSString*)fmtLimitOrderTimeShowString:(NSString*)time
{
    NSTimeInterval ts = [self parseBitsharesTimeString:time];
    
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy/MM/dd"];
    return [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970:ts]];
}

/**
 *  格式化：帐号历史日期显示格式。REMARK：以当前时区格式化，BTS默认时间是UTC。北京时间当前时区会+8。
 */
+ (NSString*)fmtAccountHistoryTimeShowString:(NSString*)time
{
    if (!time || [time isEqualToString:@""]){
        return @"00-00 00:00";
    }
    NSTimeInterval ts = [self parseBitsharesTimeString:time];
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"MM-dd HH:mm"];
    return [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970:ts]];
}

/**
 *  格式化：喂价发布日期。
 */
+ (NSString*)fmtFeedPublishDateString:(NSString*)time
{
    NSTimeInterval ts = [self parseBitsharesTimeString:time];
    
    NSDate* now = [NSDate date];
    NSTimeInterval now_ts = [now timeIntervalSince1970];
    
    NSInteger diff_ts = (NSInteger)MAX(now_ts - ts, 0);
    
    if (diff_ts < 60){
        return [NSString stringWithFormat:NSLocalizedString(@"kVcFeedNsecAgo", @"%@秒前"), @(diff_ts)];
    } else if (diff_ts < 3600){
        int min = (int)(diff_ts / 60);
        return [NSString stringWithFormat:NSLocalizedString(@"kVcFeedNminAgo", @"%@分前"), @(min)];
    } else if (diff_ts < 86400){
        int hour = (int)(diff_ts / 3600);
        return [NSString stringWithFormat:NSLocalizedString(@"kVcFeedNhourAgo", @"%@小时前"), @(hour)];
    }else{
        int day = (int)(diff_ts / 86400);
        return [NSString stringWithFormat:NSLocalizedString(@"kVcFeedNDayAgo", @"%d天前"), day];
    }
}

/**
 *  格式化：解冻周期。
 */
+ (NSString*)fmtVestingPeriodDateString:(NSUInteger)seconds
{
    if (seconds < 60){
        return [NSString stringWithFormat:NSLocalizedString(@"kVestingCellPeriodSec", @"%@秒"), @(seconds)];
    } else if (seconds < 3600){
        int min = (int)(seconds / 60);
        return [NSString stringWithFormat:NSLocalizedString(@"kVestingCellPeriodMin", @"%@分"), @(min)];
    } else if (seconds < 86400){
        int hour = (int)(seconds / 3600);
        return [NSString stringWithFormat:NSLocalizedString(@"kVestingCellPeriodHour", @"%@小时"), @(hour)];
    }else{
        int day = (int)(seconds / 86400);
        return [NSString stringWithFormat:NSLocalizedString(@"kVestingCellPeriodDay", @"%@天"), @(day)];
    }
}

/**
 *  格式化：交易OP编码转换为字符串名字。
 */
+ (NSString*)opcode2opname:(NSUInteger)opcode
{
    //  TODO:多语言
    //  TODO:fowallet 进行中
    return [NSString stringWithFormat:@"未知操作：%@", @(opcode)];
}

/**
 *  (public) 根据【失去】和【得到】的资产信息计算订单方向行为（买卖、价格、数量等）
 *  priority_hash - 优先级Hash（可选）
 */
+ (NSDictionary*)calcOrderDirectionInfos:(NSDictionary*)priority_hash pay_asset_info:(id)pay_asset_info receive_asset_info:(id)receive_asset_info
{
    assert(pay_asset_info);
    assert(receive_asset_info);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    //  初始化默认优先级Hash
    if (!priority_hash){
        priority_hash  = [chainMgr genAssetBasePriorityHash];
    }
    
    id pay_asset = [chainMgr getChainObjectByID:pay_asset_info[@"asset_id"]];
    id receive_asset = [chainMgr getChainObjectByID:receive_asset_info[@"asset_id"]];
    
    //  计算base和quote资产：优先级高的资产作为 base
    NSInteger pay_asset_priority = [[priority_hash objectForKey:[pay_asset objectForKey:@"symbol"]] integerValue];
    NSInteger receive_asset_priority = [[priority_hash objectForKey:[receive_asset objectForKey:@"symbol"]] integerValue];
    
    id base_asset;
    id quote_asset;
    id base_amount;
    id quote_amount;
    BOOL issell;
    if (pay_asset_priority > receive_asset_priority){
        //  pay 作为 base 资产。支出 base，则为买入行为。
        issell = NO;
        base_asset = pay_asset;
        quote_asset = receive_asset;
        base_amount = pay_asset_info[@"amount"];
        quote_amount = receive_asset_info[@"amount"];
    }else{
        //  receive 作为 base 资产。获得 base，则为卖出行为。
        issell = YES;
        base_asset = receive_asset;
        quote_asset = pay_asset;
        base_amount = receive_asset_info[@"amount"];
        quote_amount = pay_asset_info[@"amount"];
    }
    
    //  price = base / quote
    NSInteger base_precision = [[base_asset objectForKey:@"precision"] integerValue];
    NSInteger quote_precision = [[quote_asset objectForKey:@"precision"] integerValue];
    id n_base = [NSDecimalNumber decimalNumberWithMantissa:[base_amount unsignedLongLongValue] exponent:-base_precision isNegative:NO];
    id n_quote = [NSDecimalNumber decimalNumberWithMantissa:[quote_amount unsignedLongLongValue] exponent:-quote_precision isNegative:NO];
    
    //  保留小数位数 买入行为：向上取整 卖出行为：向下取整
    NSDecimalNumberHandler* roundHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:issell ? NSRoundDown : NSRoundUp
                                                                                                  scale:base_precision
                                                                                       raiseOnExactness:NO
                                                                                        raiseOnOverflow:NO
                                                                                       raiseOnUnderflow:NO
                                                                                    raiseOnDivideByZero:NO];
    id n_price = [n_base decimalNumberByDividingBy:n_quote withBehavior:roundHandler];
    
    //  返回
    return @{@"issell":@(issell), @"base":base_asset, @"quote":quote_asset, @"n_base":n_base, @"n_quote":n_quote, @"n_price":n_price};
}

/**
 *  获取 worker 类型。0:refund 1:vesting 2:burn
 */
+ (NSInteger)getWorkerType:(NSDictionary*)worker_json_object
{
    id worker = [worker_json_object objectForKey:@"worker"];
    if (worker && [worker isKindOfClass:[NSArray class]] && [worker count] > 0){
        return [[worker firstObject] integerValue];
    }
    //  default is vesting worker
    return (NSInteger)ebwt_vesting;
}

/**
 *  从操作的结果结构体中提取新对象ID。
 */
+ (NSString*)extractNewObjectIDFromOperationResult:(id)operation_result
{
    //  typedef fc::static_variant<void_result,object_id_type,asset> operation_result
    //  object_id_type index value is 1
    if (operation_result && [operation_result count] == 2 && [[operation_result firstObject] integerValue] == 1){
        return [operation_result objectAtIndex:1];
    }
    return nil;
}

/**
 *  从广播交易结果获取新生成的对象ID号（比如新的订单号、新HTLC号等）
 *  考虑到数据结构可能变更，加各种safe判断。
 *  REMARK：仅考虑一个 op 的情况，如果一个交易包含多个 op 则不支持。
 */
+ (NSString*)extractNewObjectID:(id)transaction_confirmation_list
{
    id new_object_id = nil;
    if (transaction_confirmation_list && [transaction_confirmation_list count] > 0){
        id trx = [transaction_confirmation_list[0] objectForKey:@"trx"];
        if (trx){
            id operation_results = [trx objectForKey:@"operation_results"];
            if (operation_results){
                id operation_result = [operation_results safeObjectAtIndex:0];
                return [self extractNewObjectIDFromOperationResult:operation_result];
            }
        }
    }
    return new_object_id;
}

/**
 *  提取OPDATA中所有的石墨烯ID信息。
 */
+ (void)extractObjectID:(NSUInteger)opcode opdata:(id)opdata container:(NSMutableDictionary*)container
{
    assert(opdata);
    assert(container);
    id fee = [opdata objectForKey:@"fee"];
    if (fee){
        [container setObject:@YES forKey:[fee objectForKey:@"asset_id"]];
    }
    //  TODO:fowallet 账号明细 、提案列表、提案确认等界面关于 OP 的描述。如果需要添加新的OP支持，需要修改。
    switch (opcode) {
        case ebo_transfer:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"from"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"to"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"amount"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_limit_order_create:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"seller"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"amount_to_sell"] objectForKey:@"asset_id"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"min_to_receive"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_limit_order_cancel:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"fee_paying_account"]];
        }
            break;
        case ebo_call_order_update:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"funding_account"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"delta_collateral"] objectForKey:@"asset_id"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"delta_debt"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_fill_order:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"account_id"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"pays"] objectForKey:@"asset_id"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"receives"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_account_create:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"registrar"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"referrer"]];
        }
            break;
        case ebo_account_update:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"account"]];
            id owner = [opdata objectForKey:@"owner"];
            if (owner){
                for (id item in [owner objectForKey:@"account_auths"]) {
                    assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
                    [container setObject:@YES forKey:[item firstObject]];
                }
            }
            id active = [opdata objectForKey:@"active"];
            if (active){
                for (id item in [active objectForKey:@"account_auths"]) {
                    assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
                    [container setObject:@YES forKey:[item firstObject]];
                }
            }
        }
            break;
        case ebo_account_whitelist:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"authorizing_account"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"account_to_list"]];
        }
            break;
        case ebo_account_upgrade:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"account_to_upgrade"]];
        }
            break;
        case ebo_account_transfer:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"account_id"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"new_owner"]];
        }
            break;
        case ebo_asset_create:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"issuer"]];
        }
            break;
        case ebo_asset_update:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"issuer"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"asset_to_update"]];
        }
            break;
        case ebo_asset_update_bitasset:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"issuer"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"asset_to_update"]];
        }
            break;
        case ebo_asset_update_feed_producers:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"issuer"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"asset_to_update"]];
        }
            break;
        case ebo_asset_issue:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"issuer"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"issue_to_account"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"asset_to_issue"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_asset_reserve:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"payer"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"amount_to_reserve"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_asset_fund_fee_pool:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"from_account"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"asset_id"]];
        }
            break;
        case ebo_asset_settle:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"account"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"amount"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_asset_global_settle:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"issuer"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"asset_to_settle"]];
        }
            break;
        case ebo_asset_publish_feed:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"publisher"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"asset_id"]];
        }
            break;
        case ebo_witness_create:
        {
            //  TODO:
        }
            break;
        case ebo_witness_update:
        {
            //  TODO:
        }
            break;
        case ebo_proposal_create:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"fee_paying_account"]];
        }
            break;
        case ebo_proposal_update:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"fee_paying_account"]];
        }
            break;
        case ebo_proposal_delete:
        {
            //  TODO:
        }
            break;
        case ebo_withdraw_permission_create:
        {
            //  TODO:
        }
            break;
        case ebo_withdraw_permission_update:
        {
            //  TODO:
        }
            break;
        case ebo_withdraw_permission_claim:
        {
            //  TODO:
        }
            break;
        case ebo_withdraw_permission_delete:
        {
            //  TODO:
        }
            break;
        case ebo_committee_member_create:
        {
            //  TODO:
        }
            break;
        case ebo_committee_member_update:
        {
            //  TODO:
        }
            break;
        case ebo_committee_member_update_global_parameters:
        {
            //  TODO:
        }
            break;
        case ebo_vesting_balance_create:
        {
            //  TODO:
        }
            break;
        case ebo_vesting_balance_withdraw:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"owner"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"amount"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_worker_create:
        {
            //  TODO:
        }
            break;
        case ebo_custom:
        {
            //  TODO:
        }
            break;
        case ebo_assert:
        {
            //  TODO:
        }
            break;
        case ebo_balance_claim:
        {
            //  TODO:
        }
            break;
        case ebo_override_transfer:
        {
            //  TODO:
        }
            break;
        case ebo_transfer_to_blind:
        {
            //  TODO:
        }
            break;
        case ebo_blind_transfer:
        {
            //  TODO:
        }
            break;
        case ebo_transfer_from_blind:
        {
            //  TODO:
        }
            break;
        case ebo_asset_settle_cancel:
        {
            //  TODO:
        }
            break;
        case ebo_asset_claim_fees:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"issuer"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"amount_to_claim"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_fba_distribute:
        {
            //  TODO:2.1 fowallet 未完成
        }
            break;
        case ebo_bid_collateral:
        {
            //  TODO:2.1 fowallet 未完成
        }
            break;
        case ebo_execute_bid:
        {
            //  TODO:2.1 fowallet 未完成
        }
            break;
        case ebo_asset_claim_pool:
        {
            //  TODO:2.1 fowallet 未完成
        }
            break;
        case ebo_asset_update_issuer:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"issuer"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"asset_to_update"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"new_issuer"]];
        }
            break;
        case ebo_htlc_create:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"from"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"to"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"amount"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_htlc_redeem:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"redeemer"]];
        }
            break;
        case ebo_htlc_redeemed:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"redeemer"]];
            [container setObject:@YES forKey:[opdata objectForKey:@"to"]];
            [container setObject:@YES forKey:[[opdata objectForKey:@"amount"] objectForKey:@"asset_id"]];
        }
            break;
        case ebo_htlc_extend:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"update_issuer"]];
        }
            break;
        case ebo_htlc_refund:
        {
            [container setObject:@YES forKey:[opdata objectForKey:@"to"]];
        }
            break;
        default:
            break;
    }
}

/**
 *  转换OP数据为UI显示数据。
 */
+ (NSDictionary*)processOpdata2UiData:(NSUInteger)opcode opdata:(id)opdata opresult:(id)opresult isproposal:(BOOL)isproposal
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    ThemeManager* theme =  [ThemeManager sharedThemeManager];
    
#define GRAPHENE_NAME(key)          [[chainMgr getChainObjectByID:opdata[key]] objectForKey:@"name"]
#define GRAPHENE_ASSET_SYMBOL(key)  [[chainMgr getChainObjectByID:opdata[key]] objectForKey:@"symbol"]
#define GRAPHENE_ASSET_N(key)       [self formatAssetAmountItem:opdata[key]]
    
    NSString* name = nil;
    NSString* desc = nil;
    UIColor* color = nil;
    
    switch (opcode) {
        case ebo_transfer:
        {
            name = NSLocalizedString(@"kOpType_transfer", @"转账");
            id from = GRAPHENE_NAME(@"from");
            id to = GRAPHENE_NAME(@"to");
            id str_amount = GRAPHENE_ASSET_N(@"amount");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_transfer", @"%@ 转账 %@ 到 %@。"), from, str_amount, to];
        }
            break;
        case ebo_limit_order_create:
        {
            //  luxs 提交卖单，以101.9134 SEED/CNY的价格卖出 0.0993 CNY
            id user = GRAPHENE_NAME(@"seller");
            
            //  @{@"issell":@(issell), @"base":base_asset, @"quote":quote_asset, @"n_base":n_base, @"n_quote":n_quote, @"n_price":n_price};
            id infos = [self calcOrderDirectionInfos:nil
                                      pay_asset_info:opdata[@"amount_to_sell"]
                                  receive_asset_info:opdata[@"min_to_receive"]];
            
            id base_asset = infos[@"base"];
            id quote_asset = infos[@"quote"];
            id n_price = infos[@"n_price"];
            id n_quote = infos[@"n_quote"];
            id str_price = [NSString stringWithFormat:@"%@%@/%@", [self formatFloatValue:n_price], base_asset[@"symbol"], quote_asset[@"symbol"]];
            id str_amount = [NSString stringWithFormat:@"%@%@", [self formatFloatValue:n_quote], quote_asset[@"symbol"]];
            
            if ([infos[@"issell"] boolValue]){
                name = NSLocalizedString(@"kOpType_limit_order_create_sell", @"创建卖单");
                color = theme.sellColor;
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_limit_order_create_sell", @"%@ 提交卖单，以 %@ 的价格卖出 %@。"),
                        user, str_price, str_amount];
            }else{
                name = NSLocalizedString(@"kOpType_limit_order_create_buy", @"创建买单");
                color = theme.buyColor;
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_limit_order_create_buy", @"%@ 提交买单，以 %@ 的价格买入 %@。"),
                        user, str_price, str_amount];
            }
        }
            break;
        case ebo_limit_order_cancel:
        {
            name = NSLocalizedString(@"kOpType_limit_order_cancel", @"取消订单");
            id user = GRAPHENE_NAME(@"fee_paying_account");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_limit_order_cancel", @"%@ 取消限价单 #%@。"), user, opdata[@"order"]];
        }
            break;
        case ebo_call_order_update:
        {
            name = NSLocalizedString(@"kOpType_call_order_update", @"调整债仓");
            
            id user = GRAPHENE_NAME(@"funding_account");
            
            //  REMARK：这2个字段可能为负数。
            id collateral = opdata[@"delta_collateral"];
            id debt = opdata[@"delta_debt"];
            
            id collateral_asset = [chainMgr getChainObjectByID:collateral[@"asset_id"]];
            id debt_asset = [chainMgr getChainObjectByID:debt[@"asset_id"]];
            
            id collateral_num = [self formatAssetString:collateral[@"amount"] asset:collateral_asset];
            id debt_num = [self formatAssetString:debt[@"amount"] asset:debt_asset];
            
            id str_collateral = [NSString stringWithFormat:@"%@%@", collateral_num, collateral_asset[@"symbol"]];
            id str_debt = [NSString stringWithFormat:@"%@%@", debt_num, debt_asset[@"symbol"]];
            
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_call_order_update", @"%@ 更新保证金 %@，借出 %@。"),
                    user, str_collateral, str_debt];
        }
            break;
        case ebo_fill_order:
        {
            name = NSLocalizedString(@"kOpType_fill_order", @"订单成交");
            
            id user = GRAPHENE_NAME(@"account_id");
            
            BOOL isCallOrder = [[[opdata[@"order_id"] componentsSeparatedByString:@"."] objectAtIndex:1] integerValue] == ebot_call_order;
            
            //  @{@"issell":@(issell), @"base":base_asset, @"quote":quote_asset, @"n_base":n_base, @"n_quote":n_quote, @"n_price":n_price};
            id infos = [self calcOrderDirectionInfos:nil
                                      pay_asset_info:opdata[@"pays"]
                                  receive_asset_info:opdata[@"receives"]];
            
            id base_asset = infos[@"base"];
            id quote_asset = infos[@"quote"];
            id n_price = infos[@"n_price"];
            id n_quote = infos[@"n_quote"];
            id str_price = [NSString stringWithFormat:@"%@%@/%@", [self formatFloatValue:n_price], base_asset[@"symbol"], quote_asset[@"symbol"]];
            id str_amount = [NSString stringWithFormat:@"%@%@", [self formatFloatValue:n_quote], quote_asset[@"symbol"]];
            
            if ([infos[@"issell"] boolValue]){
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_fill_order_sell", @"%@ 以 %@ 的价格卖出 %@。"),
                        user, str_price, str_amount];
            }else{
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_fill_order_buy", @"%@ 以 %@ 的价格买入 %@。"),
                        user, str_price, str_amount];
            }
            if (isCallOrder){
                color = theme.callOrderColor;
            }
        }
            break;
        case ebo_account_create:
        {
            name = NSLocalizedString(@"kOpType_account_create", @"创建帐号");
            id user = GRAPHENE_NAME(@"registrar");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_account_create", @"%@ 创建帐号 %@。"), user, opdata[@"name"]];
        }
            break;
        case ebo_account_update:
        {
            name = NSLocalizedString(@"kOpType_account_update", @"更新账户");
            id user = GRAPHENE_NAME(@"account");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_account_update", @"%@ 更新账户信息。"), user];
        }
            break;
        case ebo_account_whitelist:
        {
            name = NSLocalizedString(@"kOpType_account_whitelist", @"账号白名单");
            NSInteger new_listing_flag = [[opdata objectForKey:@"new_listing"] integerValue];
            BOOL in_white_list = (new_listing_flag & ebwlf_white_listed) != 0;
            BOOL in_black_list = (new_listing_flag & ebwlf_black_listed) != 0;
            if (in_white_list && in_black_list){
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_account_whitelist_both", @"%@ 添加 %@ 到白名单和黑名单列表。"), GRAPHENE_NAME(@"authorizing_account"), GRAPHENE_NAME(@"account_to_list")];
            }else if (in_white_list){
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_account_whitelist_white", @"%@ 添加 %@ 到白名单列表。"), GRAPHENE_NAME(@"authorizing_account"), GRAPHENE_NAME(@"account_to_list")];
            }else if (in_black_list){
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_account_whitelist_black", @"%@ 添加 %@ 到黑名单列表。"), GRAPHENE_NAME(@"authorizing_account"), GRAPHENE_NAME(@"account_to_list")];
            }else{
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_account_whitelist_none", @"%@ 从黑白名单列表移除 %@。"), GRAPHENE_NAME(@"authorizing_account"), GRAPHENE_NAME(@"account_to_list")];
            }
        }
            break;
        case ebo_account_upgrade:
        {
            name = NSLocalizedString(@"kOpType_account_upgrade", @"升级账户");
            id user = GRAPHENE_NAME(@"account_to_upgrade");
            if ([opdata[@"upgrade_to_lifetime_member"] boolValue]){
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_account_upgrade_member", @"%@ 升级终身会员。"), user];
            }else{
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_account_upgrade", @"%@ 升级账户。"), user];
            }
        }
            break;
        case ebo_account_transfer:
        {
            name = NSLocalizedString(@"kOpType_account_transfer", @"账号转移");
            desc = NSLocalizedString(@"kOpDesc_account_transfer", @"转移账号。");
            //  TODO:待细化
        }
            break;
        case ebo_asset_create:
        {
            name = NSLocalizedString(@"kOpType_asset_create", @"创建资产");
            id user = GRAPHENE_NAME(@"issuer");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_asset_create", @"%@ 创建资产 %@。"), user, opdata[@"symbol"]];
        }
            break;
        case ebo_asset_update:
        {
            name = NSLocalizedString(@"kOpType_asset_update", @"更新资产");
            id symbol = GRAPHENE_ASSET_SYMBOL(@"asset_to_update");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_asset_update", @"更新资产 %@。"), symbol];
        }
            break;
        case ebo_asset_update_bitasset:
        {
            name = NSLocalizedString(@"kOpType_asset_update_bitasset", @"更新智能币");
            desc = NSLocalizedString(@"kOpDesc_asset_update_bitasset", @"更新智能资产信息");
            //  TODO:待细化
        }
            break;
        case ebo_asset_update_feed_producers:
        {
            name = NSLocalizedString(@"kOpType_asset_update_feed_producers", @"更新喂价者");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_asset_update_feed_producers", @"%@ 资产更新发布喂价的账号信息。"), GRAPHENE_ASSET_SYMBOL(@"asset_to_update")];
        }
            break;
        case ebo_asset_issue:
        {
            name = NSLocalizedString(@"kOpType_asset_issue", @"资产发行");
            desc = NSLocalizedString(@"kOpDesc_asset_issue", @"资产发行。");
            //  TODO:待细化
        }
            break;
        case ebo_asset_reserve:
        {
            name = NSLocalizedString(@"kOpType_asset_reserve", @"资产销毁");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_asset_reserve", @"%@ 销毁 %@。"),
                    GRAPHENE_NAME(@"payer"),
                    GRAPHENE_ASSET_N(@"amount_to_reserve")];
        }
            break;
        case ebo_asset_fund_fee_pool:
        {
            name = NSLocalizedString(@"kOpType_asset_fund_fee_pool", @"注资手续费池");
            desc = NSLocalizedString(@"kOpDesc_asset_fund_fee_pool", @"注资手续费池。");
            //  TODO:待细化
        }
            break;
        case ebo_asset_settle:
        {
            name = NSLocalizedString(@"kOpType_asset_settle", @"资产强清");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_asset_settle", @"%@ 强清 %@。"),
                    GRAPHENE_NAME(@"account"),
                    GRAPHENE_ASSET_N(@"amount")];
        }
            break;
        case ebo_asset_global_settle:
        {
            name = NSLocalizedString(@"kOpType_asset_global_settle", @"资产全局清算");
            desc = NSLocalizedString(@"kOpDesc_asset_global_settle", @"资产全局清算。");
            //  TODO:待细化
        }
            break;
        case ebo_asset_publish_feed:
        {
            name = NSLocalizedString(@"kOpType_asset_publish_feed", @"发布喂价");
            desc = NSLocalizedString(@"kOpDesc_asset_publish_feed", @"发布资产喂价。");
            //  TODO:待细化
        }
            break;
        case ebo_witness_create:
        {
            name = NSLocalizedString(@"kOpType_witness_create", @"创建见证人");
            desc = NSLocalizedString(@"kOpDesc_witness_create", @"创建见证人。");
            //  TODO:待细化
        }
            break;
        case ebo_witness_update:
        {
            name = NSLocalizedString(@"kOpType_witness_update", @"更新见证人");
            desc = NSLocalizedString(@"kOpDesc_witness_update", @"更新见证人信息。");
            //  TODO:待细化
        }
            break;
        case ebo_proposal_create:
        {
            name = NSLocalizedString(@"kOpType_proposal_create", @"创建提案");
            id new_proposal_id = [self extractNewObjectIDFromOperationResult:opresult];
            if (new_proposal_id){
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_proposal_create_with_id", @"%@ 创建提案。#%@"), GRAPHENE_NAME(@"fee_paying_account"), new_proposal_id];
            }else{
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_proposal_create", @"%@ 创建提案。"), GRAPHENE_NAME(@"fee_paying_account")];
            }
        }
            break;
        case ebo_proposal_update:
        {
            name = NSLocalizedString(@"kOpType_proposal_update", @"更新提案");
            id user = GRAPHENE_NAME(@"fee_paying_account");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_proposal_update", @"%@ 更新提案。#%@"), user, opdata[@"proposal"]];
        }
            break;
        case ebo_proposal_delete:
        {
            name = NSLocalizedString(@"kOpType_proposal_delete", @"删除提案");
            desc = NSLocalizedString(@"kOpDesc_proposal_delete", @"删除提案。");
            //  TODO:待细化
        }
            break;
        case ebo_withdraw_permission_create:
        {
            name = NSLocalizedString(@"kOpType_withdraw_permission_create", @"创建授权提款");
            desc = NSLocalizedString(@"kOpDesc_withdraw_permission_create", @"创建授权提款。");
            //  TODO:待细化
        }
            break;
        case ebo_withdraw_permission_update:
        {
            name = NSLocalizedString(@"kOpType_withdraw_permission_update", @"更新授权提款");
            desc = NSLocalizedString(@"kOpDesc_withdraw_permission_update", @"更新授权提款。");
            //  TODO:待细化
        }
            break;
        case ebo_withdraw_permission_claim:
        {
            name = NSLocalizedString(@"kOpType_withdraw_permission_claim", @"提取授权提款");
            desc = NSLocalizedString(@"kOpDesc_withdraw_permission_claim", @"提取授权提款。");
            //  TODO:待细化
        }
            break;
        case ebo_withdraw_permission_delete:
        {
            name = NSLocalizedString(@"kOpType_withdraw_permission_delete", @"删除授权提款");
            desc = NSLocalizedString(@"kOpDesc_withdraw_permission_delete", @"删除授权提款。");
            //  TODO:待细化
        }
            break;
        case ebo_committee_member_create:
        {
            name = NSLocalizedString(@"kOpType_committee_member_create", @"创建理事会成员");
            desc = NSLocalizedString(@"kOpDesc_committee_member_create", @"创建理事会成员。");
            //  TODO:待细化
        }
            break;
        case ebo_committee_member_update:
        {
            name = NSLocalizedString(@"kOpType_committee_member_update", @"更新理事会成员");
            desc = NSLocalizedString(@"kOpDesc_committee_member_update", @"更新理事会成员。");
            //  TODO:待细化
        }
            break;
        case ebo_committee_member_update_global_parameters:
        {
            name = NSLocalizedString(@"kOpType_committee_member_update_global_parameters", @"更新系统参数");
            desc = NSLocalizedString(@"kOpDesc_committee_member_update_global_parameters", @"更新全局系统参数。");
            //  TODO:待细化
        }
            break;
        case ebo_vesting_balance_create:
        {
            name = NSLocalizedString(@"kOpType_vesting_balance_create", @"创建待解冻金额");
            desc = NSLocalizedString(@"kOpDesc_vesting_balance_create", @"创建待解冻金额。");
            //  TODO:待细化
        }
            break;
        case ebo_vesting_balance_withdraw:
        {
            name = NSLocalizedString(@"kOpType_vesting_balance_withdraw", @"提取待解冻金额");
            id user = GRAPHENE_NAME(@"owner");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_vesting_balance_withdraw", @"%@ 提取待解冻金额 %@"),
                    user,  GRAPHENE_ASSET_N(@"amount")];
        }
            break;
        case ebo_worker_create:
        {
            name = NSLocalizedString(@"kOpType_worker_create", @"创建预算项目");
            desc = NSLocalizedString(@"kOpDesc_worker_create", @"创建预算项目。");
            //  TODO:待细化
        }
            break;
        case ebo_custom:
        {
            name = NSLocalizedString(@"kOpType_custom", @"自定义");
            desc = NSLocalizedString(@"kOpDesc_custom", @"自定义内容。");
            //  TODO:待细化
        }
            break;
        case ebo_assert:
        {
            name = NSLocalizedString(@"kOpType_assert", @"断言");
            desc = NSLocalizedString(@"kOpDesc_assert", @"断言。");
            //  TODO:待细化
        }
            break;
        case ebo_balance_claim:
        {
            name = NSLocalizedString(@"kOpType_balance_claim", @"提取余额");//TODO
            desc = NSLocalizedString(@"kOpDesc_balance_claim", @"提取余额。");
            //  TODO:待细化
        }
            break;
        case ebo_override_transfer:
        {
            name = NSLocalizedString(@"kOpType_override_transfer", @"回收资产");//TODO:
            desc = NSLocalizedString(@"kOpDesc_override_transfer", @"回收资产。");
            //  TODO:待细化
        }
            break;
        case ebo_transfer_to_blind:
        {
            name = NSLocalizedString(@"kOpType_transfer_to_blind", @"转到隐私账户");
            desc = NSLocalizedString(@"kOpDesc_transfer_to_blind", @"向隐私账号转账。");
            //  TODO:待细化
        }
            break;
        case ebo_blind_transfer:
        {
            name = NSLocalizedString(@"kOpType_blind_transfer", @"隐私转账");
            desc = NSLocalizedString(@"kOpDesc_blind_transfer", @"隐私转账。");
            //  TODO:待细化
        }
            break;
        case ebo_transfer_from_blind:
        {
            name = NSLocalizedString(@"kOpType_transfer_from_blind", @"从隐私账户转出");
            desc = NSLocalizedString(@"kOpDesc_transfer_from_blind", @"从隐私账户转出 。");
            //  TODO:待细化
        }
            break;
        case ebo_asset_settle_cancel:
        {
            name = NSLocalizedString(@"kOpType_asset_settle_cancel", @"取消清算");
            desc = NSLocalizedString(@"kOpDesc_asset_settle_cancel", @"取消清算。");
            //  TODO:待细化
        }
            break;
        case ebo_asset_claim_fees:
        {
            name = NSLocalizedString(@"kOpType_asset_claim_fees", @"提取资产手续费");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_asset_claim_fees", @"%@ 提取 %@ 资产手续费。"),
                    GRAPHENE_NAME(@"issuer"),
                    GRAPHENE_ASSET_N(@"amount_to_claim")];
        }
            break;
        case ebo_fba_distribute:
        {
            name = NSLocalizedString(@"kOpType_fba_distribute", @"FBA分发");
            desc = NSLocalizedString(@"kOpDesc_fba_distribute", @"FBA分发。");
            //  TODO:待细化
        }
            break;
        case ebo_bid_collateral:
        {
            name = NSLocalizedString(@"kOpType_bid_collateral", @"黑天鹅竞价");
            desc = NSLocalizedString(@"kOpDesc_bid_collateral", @"黑天鹅竞价。");
            //  TODO:待细化
        }
            break;
        case ebo_execute_bid:
        {
            name = NSLocalizedString(@"kOpType_execute_bid", @"竞价成功");
            desc = NSLocalizedString(@"kOpDesc_execute_bid", @"竞价成功。");
            //  TODO:待细化
        }
            break;
        case ebo_asset_claim_pool:
        {
            name = NSLocalizedString(@"kOpType_asset_claim_pool", @"提取资产手续费池");
            desc = NSLocalizedString(@"kOpDesc_asset_claim_pool", @"提取手续费池资产。");
            //  TODO:待细化
        }
            break;
        case ebo_asset_update_issuer:
        {
            name = NSLocalizedString(@"kOpType_asset_update_issuer", @"更新资产发行账号");
            id issuer = GRAPHENE_NAME(@"issuer");
            id asset_to_update = GRAPHENE_ASSET_SYMBOL(@"asset_to_update");
            id new_issuer = GRAPHENE_NAME(@"new_issuer");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_asset_update_issuer", @"%@ 更新 %@ 资产的所有者账号为 %@。"),
                    issuer, asset_to_update, new_issuer];
        }
            break;
        case ebo_htlc_create:
        {
            name = NSLocalizedString(@"kOpType_htlc_create", @"创建合约转账");
            id from = GRAPHENE_NAME(@"from");
            id to = GRAPHENE_NAME(@"to");
            id str_amount = GRAPHENE_ASSET_N(@"amount");
            
            id new_htlc_id = [self extractNewObjectIDFromOperationResult:opresult];
            if (new_htlc_id){
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_htlc_create_with_id", @"%@ 准备转账 %@ 到 %@。#%@"),
                        from, str_amount, to, new_htlc_id];
            }else{
                desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_htlc_create", @"%@ 准备转账 %@ 到 %@。"), from, str_amount, to];
            }
        }
            break;
        case ebo_htlc_redeem:
        {
            name = NSLocalizedString(@"kOpType_htlc_redeem", @"执行合约转账");
            
            NSString* hex_preimage = opdata[@"preimage"];
            assert([OrgUtils isValidHexString:hex_preimage]);
            
            NSInteger hex_len = [hex_preimage length];
            NSInteger raw_len = hex_len / 2;
            assert(raw_len > 0);
            
            unsigned char raw_preimage[raw_len];
            hex_decode((const unsigned char*)[hex_preimage UTF8String], hex_len, raw_preimage);
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_htlc_redeem", @"%@ 使用原像 %@ 赎回HTLC。#%@"),
                    GRAPHENE_NAME(@"redeemer"),
                    [[NSString alloc] initWithBytes:raw_preimage length:raw_len encoding:NSUTF8StringEncoding],
                    opdata[@"htlc_id"]];
        }
            break;
        case ebo_htlc_redeemed:
        {
            name = NSLocalizedString(@"kOpType_htlc_redeemed", @"转账合约已执行");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_htlc_redeemed", @"%@ 赎回HTLC成功，%@ 转入账号 %@。#%@"),
                    GRAPHENE_NAME(@"redeemer"),
                    GRAPHENE_ASSET_N(@"amount"),
                    GRAPHENE_NAME(@"to"),
                    opdata[@"htlc_id"]];
        }
            break;
        case ebo_htlc_extend:
        {
            name = NSLocalizedString(@"kOpType_htlc_extend", @"更新合约");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_htlc_extend", @"%@ 延长HTLC有效期 %@ 秒。#%@"),
                    GRAPHENE_NAME(@"update_issuer"),
                    opdata[@"seconds_to_add"],
                    opdata[@"htlc_id"]];
        }
            break;
        case ebo_htlc_refund:
        {
            name = NSLocalizedString(@"kOpType_htlc_refund", @"合约转账退款");
            id to = GRAPHENE_NAME(@"to");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_htlc_refund", @"HTLC过期，资产自动退回到账号 %@。#%@"), to, opdata[@"htlc_id"]];
        }
            break;
        default:
        {
            name = NSLocalizedString(@"kOpType_unknown_op", @"未知操作");
            desc = [NSString stringWithFormat:NSLocalizedString(@"kOpDesc_unknown_op", @"未知的操作 #%@。"), @(opcode)];
        }
            break;
    }
    assert(name && desc);
    if (isproposal){
        name = [NSString stringWithFormat:NSLocalizedString(@"kOpType_proposal_prefix", @"提议%@"), name];
    }
    
#undef GRAPHENE_NAME
#undef GRAPHENE_ASSET_SYMBOL
#undef GRAPHENE_ASSET_N
    
    return @{@"name":name, @"desc":desc, @"color":color ?: theme.textColorMain};
}

/**
 *  (public) 计算在爆仓时最少需要卖出的资产数量，如果没设置目标抵押率则全部卖出。如果有设置则根据目标抵押率计算。
 */
+ (NSDecimalNumber*)calcSettlementSellNumbers:(id)call_order
                               debt_precision:(NSInteger)debt_precision
                         collateral_precision:(NSInteger)collateral_precision
                                   feed_price:(NSDecimalNumber*)feed_price
                                   call_price:(NSDecimalNumber*)call_price
                                          mcr:(NSDecimalNumber*)mcr
                                         mssr:(NSDecimalNumber*)mssr
{
    assert(call_order);
    assert(feed_price);
    assert(mcr);
    assert(mssr);
    
    id collateral = [call_order objectForKey:@"collateral"];
    assert(collateral);
    id debt = [call_order objectForKey:@"debt"];
    assert(debt);
    
    NSDecimalNumber* n_collateral = [NSDecimalNumber decimalNumberWithMantissa:[collateral unsignedLongLongValue]
                                                                      exponent:-collateral_precision isNegative:NO];
    NSDecimalNumber* n_debt = [NSDecimalNumber decimalNumberWithMantissa:[debt unsignedLongLongValue]
                                                                exponent:-debt_precision isNegative:NO];
    
    NSDecimalNumberHandler* ceil_handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                  scale:collateral_precision
                                                                                       raiseOnExactness:NO
                                                                                        raiseOnOverflow:NO
                                                                                       raiseOnUnderflow:NO
                                                                                    raiseOnDivideByZero:NO];
    
    id target_collateral_ratio = [call_order objectForKey:@"target_collateral_ratio"];
    if (target_collateral_ratio){
        //  卖出部分，只要抵押率回到目标抵押率即可。
        //  =============================================================
        //  公式：n为最低卖出数量
        //  即 新抵押率 = 新总估值 / 新总负债
        //
        //  (collateral - n) * feed_price
        //  -----------------------------  >= target_collateral_ratio
        //  (debt - n * feed_price / mssr)
        //
        //  即:
        //          target_collateral_ratio * debt - feed_price * collateral
        //  n >= --------------------------------------------------------------
        //          feed_price * (target_collateral_ratio / mssr - 1)
        //  =============================================================
        
        id n_target_collateral_ratio = [NSDecimalNumber decimalNumberWithMantissa:[target_collateral_ratio unsignedLongLongValue]
                                                                         exponent:-3 isNegative:NO];
        
        //  目标抵押率和MCR之间取最大值
        if ([n_target_collateral_ratio compare:mcr] < 0) {
            n_target_collateral_ratio = mcr;
        }
        
        //  开始计算
        id n1 = [[n_target_collateral_ratio decimalNumberByMultiplyingBy:n_debt] decimalNumberBySubtracting:[feed_price decimalNumberByMultiplyingBy:n_collateral]];
        
        id n2 = [feed_price decimalNumberByMultiplyingBy:[[n_target_collateral_ratio decimalNumberByDividingBy:mssr] decimalNumberBySubtracting:[NSDecimalNumber one]]];
        
        return [n1 decimalNumberByDividingBy:n2 withBehavior:ceil_handler];
    }else{
        //  卖出部分，覆盖所有债务即可。
        return [n_debt decimalNumberByDividingBy:call_price withBehavior:ceil_handler];
    }
}

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
                          set_divide_precision:(BOOL)set_divide_precision
{
    NSDecimalNumber* n_debt = [NSDecimalNumber decimalNumberWithMantissa:[debt_amount unsignedLongLongValue]
                                                                exponent:-debt_precision isNegative:NO];
    NSDecimalNumber* n_collateral = [NSDecimalNumber decimalNumberWithMantissa:[collateral_amount unsignedLongLongValue]
                                                                      exponent:-collateral_precision isNegative:NO];
    
    id n = [n_debt decimalNumberByMultiplyingBy:n_mcr];
    if (set_divide_precision){
        if (!ceil_handler){
            ceil_handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                  scale:reverse ? collateral_precision : debt_precision
                                                                       raiseOnExactness:NO
                                                                        raiseOnOverflow:NO
                                                                       raiseOnUnderflow:NO
                                                                    raiseOnDivideByZero:NO];
        }
        if (reverse){
            n = [[NSDecimalNumber one] decimalNumberByDividingBy:[n decimalNumberByDividingBy:n_collateral] withBehavior:ceil_handler];
        }else{
            n = [n decimalNumberByDividingBy:n_collateral withBehavior:ceil_handler];
        }
    }else{
        if (reverse){
            n = [[NSDecimalNumber one] decimalNumberByDividingBy:[n decimalNumberByDividingBy:n_collateral]];
        }else{
            n = [n decimalNumberByDividingBy:n_collateral];
        }
    }
    
    return n;
}

/**
 *  (public) 合并普通盘口信息和爆仓单信息。
 */
+ (NSDictionary*)mergeOrderBook:(NSDictionary*)normal_order_book settlement_data:(NSDictionary*)settlement_data
{
    assert(normal_order_book);
    
    if (settlement_data && [[settlement_data objectForKey:@"settlement_account_number"] integerValue] > 0){
        id bidArray = [normal_order_book objectForKey:@"bids"];
        id askArray = [normal_order_book objectForKey:@"asks"];
        
        id n_call_price = [settlement_data objectForKey:@"call_price_market"];
        double f_call_price = [n_call_price doubleValue];
        
        NSMutableArray* new_array = [NSMutableArray array];
        double new_amount_sum = 0;
        BOOL inserted = NO;
        BOOL invert = [[settlement_data objectForKey:@"invert"] boolValue];
        
        for (id order in invert ? bidArray : askArray) {
            id price = [order objectForKey:@"price"];
            id quote = [order objectForKey:@"quote"];
            double f_price = [price doubleValue];
            double f_quote = [quote doubleValue];
            BOOL keep;
            if (invert){
                keep = f_price > f_call_price;
            }else{
                keep = f_price < f_call_price;
            }
            if (keep){
                new_amount_sum += f_quote;
                [new_array addObject:order];
                continue;
            }
            
            if (!inserted){
                //  insert
                double quote_amount;
                double base_amount;
                double total_sell_amount = [[settlement_data objectForKey:@"total_sell_amount"] doubleValue];
                double total_buy_amount = [[settlement_data objectForKey:@"total_buy_amount"] doubleValue];
                if (invert){
                    quote_amount = total_buy_amount;
                    base_amount = total_sell_amount;
                }else{
                    quote_amount = total_sell_amount;
                    base_amount = total_buy_amount;
                }
                new_amount_sum += quote_amount;
                [new_array addObject:@{@"price":@(f_call_price),
                                       @"quote":@(quote_amount),
                                       @"base":@(base_amount),
                                       @"sum":@(new_amount_sum), @"iscall":@YES}];
                inserted = YES;
            }
            
            new_amount_sum += f_quote;
            id base = [order objectForKey:@"base"];
            [new_array addObject:@{@"price":price, @"quote":quote, @"base":base, @"sum":@(new_amount_sum)}];
        }
        if (invert){
            bidArray = new_array;
        }else{
            askArray = new_array;
        }
        
        //  返回新的 order book
        return @{@"bids":bidArray, @"asks":askArray};
    }else{
        return normal_order_book;
    }
}

/**
 *  计算资产真实价格
 */
+ (double)calcAssetRealPrice:(id)amount precision:(NSInteger)precision
{
    unsigned long long d = [amount unsignedLongLongValue];
    double fPrecision = pow(10, precision);
    return d / fPrecision;
}

/**
 *  根据 price_item 计算价格。REMARK：price_item 包含 base 和 quote 对象，base 和 quote 包含 asset_id 和 amount 字段。
 */
+ (NSDecimalNumber*)calcPriceFromPriceObject:(id)price_item
                                     base_id:(NSString*)base_id
                              base_precision:(NSInteger)base_precision
                             quote_precision:(NSInteger)quote_precision
                                      invert:(BOOL)invert
                                roundingMode:(NSRoundingMode)roundingMode
                        set_divide_precision:(BOOL)set_divide_precision
{
    id item01 = [price_item objectForKey:@"base"];
    id item02 = [price_item objectForKey:@"quote"];
    id base = nil;
    id quote = nil;
    if ([[item01 objectForKey:@"asset_id"] isEqualToString:base_id]){
        base = item01;
        quote = item02;
    }else{
        base = item02;
        quote = item01;
    }
    
    unsigned long long i_base_amount = [[base objectForKey:@"amount"] unsignedLongLongValue];
    unsigned long long i_quote_amount = [[quote objectForKey:@"amount"] unsignedLongLongValue];
    //  REMARK：价格失效（比如喂价过期等情况）
    if (i_base_amount == 0 || i_quote_amount == 0){
        return nil;
    }
    
    id n_base = [NSDecimalNumber decimalNumberWithMantissa:i_base_amount exponent:-base_precision isNegative:NO];
    id n_quote = [NSDecimalNumber decimalNumberWithMantissa:i_quote_amount exponent:-quote_precision isNegative:NO];

    if (set_divide_precision){
        NSInteger precision = invert ? base_precision : quote_precision;
        NSDecimalNumberHandler* handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:roundingMode
                                                                                                 scale:precision
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
        if (invert){
            return [n_base decimalNumberByDividingBy:n_quote withBehavior:handler];
        }else{
            return [n_quote decimalNumberByDividingBy:n_base withBehavior:handler];
        }
    }else{
        if (invert){
            return [n_base decimalNumberByDividingBy:n_quote];
        }else{
            return [n_quote decimalNumberByDividingBy:n_base];
        }
    }
}

/**
 *  (public) 格式化ASSET_JSON对象为价格字符串，例：2323.32BTS
 */
+ (NSString*)formatAssetAmountItem:(id)asset_json
{
    id asset_id = [asset_json objectForKey:@"asset_id"];
    id amount = [asset_json objectForKey:@"amount"];
    assert(asset_id);
    assert(amount);
    
    id asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:asset_id];
    assert(asset);
    
    id num = [OrgUtils formatAssetString:amount asset:asset];
    return  [NSString stringWithFormat:@"%@%@", num, asset[@"symbol"]];
}

/**
 *  格式化资产显示字符串，保留指定有效精度。带逗号分隔。
 */
+ (NSString*)formatAssetString:(id)amount precision:(NSInteger)precision
{
    //  unsigned long long d = [amount unsignedLongLongValue];
    long long d = [amount longLongValue];
    double fPrecision = pow(10, precision);
    double value = d / fPrecision;
    
    return [self formatFloatValue:value precision:precision];
}

+ (NSString*)formatAssetString:(id)amount asset:(id)asset
{
    assert(amount);
    assert(asset);
    return [self formatAssetString:amount precision:[[asset objectForKey:@"precision"] integerValue]];
}

/**
 *  格式化资产数量显示，如果数量太大会按照 xxK xxM形式进行显示。
 */
+ (NSString*)formatAmountString:(id)amount asset:(id)asset
{
    assert(amount);
    assert(asset);
    NSInteger precision = [[asset objectForKey:@"precision"] integerValue];
    
    id n_k = [NSDecimalNumber decimalNumberWithMantissa:1000 exponent:0 isNegative:NO];
    id n_m = [NSDecimalNumber decimalNumberWithMantissa:1000000 exponent:0 isNegative:NO];
    
    id n_amount = [NSDecimalNumber decimalNumberWithMantissa:[amount unsignedLongLongValue] exponent:-precision isNegative:NO];
    
    //  2位小数、向上取整
    NSDecimalNumberHandler* ceilHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                 scale:2
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
    
    //  !(M > n_amount)  M <= n_amount
    if ([n_m compare:n_amount] != NSOrderedDescending){
        id n_result = [n_amount decimalNumberByDividingBy:n_m withBehavior:ceilHandler];
        return [NSString stringWithFormat:@"%@M", n_result];
    }else if ([n_k compare:n_amount] != NSOrderedDescending){
        id n_result = [n_amount decimalNumberByDividingBy:n_k withBehavior:ceilHandler];
        return [NSString stringWithFormat:@"%@K", n_result];
    }else{
        return [self formatAssetString:amount precision:precision];
    }
}

/**
 *  生成资产数量多 NSDecimalNumber 对象。
 */
+ (NSDecimalNumber*)genAssetAmountDecimalNumber:(id)amount asset:(id)asset
{
    assert(amount);
    assert(asset);
    NSInteger precision = [[asset objectForKey:@"precision"] integerValue];
    return [NSDecimalNumber decimalNumberWithMantissa:[amount unsignedLongLongValue] exponent:-precision isNegative:NO];
}

/**
 *  格式化浮点数，保留指定有效精度。可指定是否带组分割符。
 *  REMARK：格式化详细说明 https://www.jianshu.com/p/29ef372c65d3
 */
+ (NSString*)formatFloatValue:(double)value precision:(NSInteger)precision usesGroupingSeparator:(BOOL)usesGroupingSeparator
{
    NSNumberFormatter* asset_formatter = [[NSNumberFormatter alloc] init];
    [asset_formatter setLocale:[LangManager sharedLangManager].appLocale];
    [asset_formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [asset_formatter setMaximumFractionDigits:precision];
    [asset_formatter setUsesGroupingSeparator:usesGroupingSeparator];
    return [asset_formatter stringFromNumber:@(value)];
}

+ (NSString*)formatFloatValue:(double)value precision:(NSInteger)precision
{
    return [self formatFloatValue:value precision:precision usesGroupingSeparator:YES];
}

+ (NSString*)formatFloatValue:(NSDecimalNumber*)value usesGroupingSeparator:(BOOL)usesGroupingSeparator
{
    NSNumberFormatter* asset_formatter = [[NSNumberFormatter alloc] init];
    [asset_formatter setLocale:[LangManager sharedLangManager].appLocale];
    [asset_formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    //  REMARK：大部分NSDecimalNumber在计算的时候就已经制定了小数点精度和四舍五入模式等，故这里直接设置一个最大小数位数即可。
    [asset_formatter setMaximumFractionDigits:14];
    [asset_formatter setUsesGroupingSeparator:usesGroupingSeparator];
    return [asset_formatter stringFromNumber:value];
}

+ (NSString*)formatFloatValue:(NSDecimalNumber*)value
{
    return [self formatFloatValue:value usesGroupingSeparator:YES];
}

/**
 *  根据 get_full_accounts 接口返回的所有用户信息计算用户所有资产信息、挂单信息、抵押信息、债务信息等。
 *  返回值 {validBalancesHash, limitValuesHash, callValuesHash, debtValuesHash}
 */
+ (NSDictionary*)calcUserAssetDetailInfos:(NSDictionary*)full_user_data
{
    //  --- 整理资产 ---
    //  a.计算所有资产的总挂单量信息
    NSMutableDictionary* limit_orders_values = [NSMutableDictionary dictionary];
    NSArray* limit_orders = [full_user_data objectForKey:@"limit_orders"];
    if (limit_orders){
        for (id order in limit_orders) {
            //  限价单卖 base 资产，卖的数量为 for_sale 字段。sell_price 只是价格信息。
            id sell_asset_id = order[@"sell_price"][@"base"][@"asset_id"];
            id sell_amount = [order objectForKey:@"for_sale"];
            //  所有挂单累加
            unsigned long long value = [limit_orders_values[sell_asset_id] unsignedLongLongValue];
            value += [sell_amount unsignedLongLongValue];
            [limit_orders_values setObject:@(value) forKey:sell_asset_id];
        }
    }
    
    //  b.计算所有资产的总抵押量信息（目前抵押资产仅有BTS）和总债务信息（CNY、USD等）
    NSMutableDictionary* call_orders_values = [NSMutableDictionary dictionary];
    NSMutableDictionary* debt_values = [NSMutableDictionary dictionary];
    NSArray* call_orders = [full_user_data objectForKey:@"call_orders"];
    if (call_orders){
        for (id order in call_orders) {
            id call_price = [order objectForKey:@"call_price"];
            //  a.计算抵押
            //  抵押资产ID
            id asset_id = [[call_price objectForKey:@"base"] objectForKey:@"asset_id"];
            id amount = [order objectForKey:@"collateral"];
            //  所有抵押累加
            unsigned long long value = [call_orders_values[asset_id] unsignedLongLongValue];
            value += [amount unsignedLongLongValue];
            [call_orders_values setObject:@(value) forKey:asset_id];
            //  b.计算债务
            id debt_asset_id = [[call_price objectForKey:@"quote"] objectForKey:@"asset_id"];
            id debt_amount = [order objectForKey:@"debt"];
            //  所有债务累加
            unsigned long long debt_value = [debt_values[debt_asset_id] unsignedLongLongValue];
            debt_value += [debt_amount unsignedLongLongValue];
            [debt_values setObject:@(debt_value) forKey:debt_asset_id];
        }
    }
    
    //  c.去掉余额为0的资产
    id validBalances = [[full_user_data objectForKey:@"balances"] ruby_select:(^BOOL(id src) {
        return [[src objectForKey:@"balance"] unsignedLongLongValue] != 0;
    })];
    NSMutableDictionary* validBalancesHash = [NSMutableDictionary dictionary];
    for (id asset in validBalances) {
        validBalancesHash[[asset objectForKey:@"asset_type"]] = asset;
    }
    
    //  d.添加必须显示的资产（BTS、有挂单没余额、有抵押没余额、有债务没余额）
    id default_asset_id = [ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID;
    id core_asset = [validBalancesHash objectForKey:default_asset_id];
    //  没余额，初始化默认值。
    if (!core_asset){
        [validBalancesHash setObject:@{@"asset_type":default_asset_id, @"balance":@0} forKey:default_asset_id];
    }
    for (id asset_id in [limit_orders_values allKeys]) {
        id asset = [validBalancesHash objectForKey:asset_id];
        //  没余额，初始化默认值。
        if (!asset){
            [validBalancesHash setObject:@{@"asset_type":asset_id, @"balance":@0} forKey:asset_id];
        }
    }
    for (id asset_id in [call_orders_values allKeys]) {
        id asset = [validBalancesHash objectForKey:asset_id];
        //  没余额，初始化默认值。
        if (!asset){
            [validBalancesHash setObject:@{@"asset_type":asset_id, @"balance":@0} forKey:asset_id];
        }
    }
    for (id asset_id in [debt_values allKeys]) {
        id asset = [validBalancesHash objectForKey:asset_id];
        //  没余额，初始化默认值。
        if (!asset){
            [validBalancesHash setObject:@{@"asset_type":asset_id, @"balance":@0} forKey:asset_id];
        }
    }
    
    //  返回
    return @{@"validBalancesHash":validBalancesHash,
             @"limitValuesHash":limit_orders_values,
             @"callValuesHash":call_orders_values,
             @"debtValuesHash":debt_values};
}

/**
 *  获取设备IP地址
 */
+ (NSString*)getIPAddress
{
    NSString* address = nil;
    struct ifaddrs* interfaces = NULL;
    struct ifaddrs* temp_addr = NULL;
    int success = 0;
    //  检索当前接口,在成功时,返回0
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // 循环链表的接口
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // 检查接口是否en0 wifi连接在iPhone上
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // 得到NSString从C字符串
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // 释放内存
    freeifaddrs(interfaces);
    return address;
}

/**
 *  16进制解码
 */
+ (NSData*)hexDecode:(NSString*)hex_string
{
    assert(hex_string);
    assert([hex_string length] > 0);
    assert(([hex_string length] % 2) == 0);
    
    size_t raw_size = [hex_string length] / 2;
    unsigned char output[raw_size];
    hex_decode((const unsigned char*)[hex_string UTF8String], (const size_t)[hex_string length], output);
    return [[NSData alloc] initWithBytes:output length:raw_size];
}

/**
 *  根据私钥种子字符串生成 WIF 格式私钥。
 */
+ (NSString*)genBtsWifPrivateKey:(NSString*)seed
{
    return [self genBtsWifPrivateKey:(const unsigned char*)[seed UTF8String] size:(size_t)[seed length]];
}

+ (NSString*)genBtsWifPrivateKey:(const unsigned char*)seed size:(size_t)seed_size
{
    assert(seed);
    assert(seed_size > 0);
    
    //  raw private key 32
    unsigned char prikey01[32] = {0, };
    __bts_gen_private_key_from_seed(seed, seed_size, prikey01);
    
    return [self genBtsWifPrivateKeyByPrivateKey32:[[NSData alloc] initWithBytes:prikey01 length:sizeof(prikey01)]];
}

/**
 *  根据32字节原始私钥生成 WIF 格式私钥
 */
+ (NSString*)genBtsWifPrivateKeyByPrivateKey32:(NSData*)private_key32
{
    assert([private_key32 length] == 32);
    
    //  wif private key
    unsigned char output[51+10] = {0, };
    size_t output_size = sizeof(output);
    __bts_private_key_to_wif((const unsigned char*)[private_key32 bytes], output, &output_size);
    return [[NSString alloc] initWithBytes:output length:output_size encoding:NSUTF8StringEncoding];
}

/**
 *  根据私钥种子字符串生成 BTS 地址字符串。
 */
+ (NSString*)genBtsAddressFromPrivateKeySeed:(NSString*)seed
{
    unsigned char prikey01[32] = {0, };
    __bts_gen_private_key_from_seed((const unsigned char*)[seed UTF8String], (const size_t)[seed length], prikey01);
    
    unsigned char output[51+10] = {0, };
    size_t output_size = sizeof(output);
    
    NSString* address_prefix = [ChainObjectManager sharedChainObjectManager].grapheneAddressPrefix;
    bool ret = __bts_gen_address_from_private_key32(prikey01, output, &output_size,
                                                    [address_prefix UTF8String], address_prefix.length);
    if (!ret){
        return nil;
    }
    
    return [[NSString alloc] initWithBytes:output length:output_size encoding:NSUTF8StringEncoding];
}

/**
 *  根据 WIF格式私钥 字符串生成 BTS 地址字符串。
 */
+ (NSString*)genBtsAddressFromWifPrivateKey:(NSString*)wif_private_key
{
    unsigned char private_key32[32] = {0, };
    
    bool ret = __bts_gen_private_key_from_wif_privatekey((const unsigned char*)[wif_private_key UTF8String], (const size_t)wif_private_key.length, private_key32);
    
    //  无效的WIF私钥
    if (!ret){
        return nil;
    }
    
    unsigned char output[51+10] = {0, };
    size_t output_size = sizeof(output);
    
    NSString* address_prefix = [ChainObjectManager sharedChainObjectManager].grapheneAddressPrefix;
    ret = __bts_gen_address_from_private_key32(private_key32, output, &output_size,
                                               [address_prefix UTF8String], address_prefix.length);
    if (!ret){
        return nil;
    }
    
    return [[NSString alloc] initWithBytes:output length:output_size encoding:NSUTF8StringEncoding];
}

/**
 *  防止数据备份到itunes或者icloud
 */
+ (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *) filePathString
{
    NSURL* URL= [NSURL fileURLWithPath: filePathString];
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
    return success;
}

+ (BOOL)moveFileFrom:(NSString*)from to:(NSString*)to andDelete:(BOOL)delete
{
    if (!from || !to)
        return NO;
    
    //  旧数据不存在 or 新数据已经存在 则不移动了。
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:from]){
        return YES;
    }
    if ([fileManager fileExistsAtPath:to]){
        return YES;
    }
    
    //  移动文件
    NSString* dirpath = [to stringByDeletingLastPathComponent];
    NSError* error = nil;
    [fileManager createDirectoryAtPath:dirpath withIntermediateDirectories:YES attributes:nil error:&error];
    if (error)
    {
        NSLog(@"createDirectoryAtPath error:%@", error);
    }
    error = nil;
    BOOL ret = [fileManager moveItemAtPath:from toPath:to error:&error];
    if (error)
    {
        NSLog(@"moveItemAtPath error:%@", error);
    }
    if (ret){
        [self addSkipBackupAttributeToItemAtPath:to];
        NSLog(@"move from:%@ to:%@ success", [from lastPathComponent], [to lastPathComponent]);
    }
    if (delete)
    {
        return [self deleteFile:from];
    }
    return ret;
}

+(BOOL)writeFileAny:(id)data withFullPath:(NSString*)fullpath withDirPath:(NSString*)dirpath
{
    if (!data || !fullpath)
        return NO;
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (!dirpath) {
        dirpath = [fullpath stringByDeletingLastPathComponent];
    }
    
    NSError* error = nil;
    [fileManager createDirectoryAtPath:dirpath withIntermediateDirectories:YES attributes:nil error:&error];

    if (error)
    {
        NSLog(@"createDirectoryAtPath error:%@", error);
    }
    
    //  生成临时文件名：写入临时文件、重命名、删除临时文件。
    NSString* tempfilename = [NSString stringWithFormat:@"%@.%@%@", fullpath, @(arc4random()), @([[NSDate date] timeIntervalSince1970])];
    if ([data writeToFile:tempfilename atomically:YES]){
        //  重命名前先删除老的
        error = nil;
        [self deleteFile:fullpath];
        BOOL ret = [fileManager moveItemAtPath:tempfilename toPath:fullpath error:&error];
        if (error)
        {
            NSLog(@"moveItemAtPath error:%@", error);
        }
        else
        {
            //  设置防止备份标记
            [self addSkipBackupAttributeToItemAtPath:fullpath];
        }
        //  删除新的
        [self deleteFile:tempfilename];
        return ret;
    }else{
        return NO;
    }
}

+(BOOL)writeFile:(NSData*)data withFullPath:(NSString*)fullpath withDirPath:(NSString*)dirpath
{
    return [self writeFileAny:data withFullPath:fullpath withDirPath:dirpath];
}

+(BOOL)writeFileArray:(NSArray*)data withFullPath:(NSString*)fullpath withDirPath:(NSString*)dirpath
{
    return [self writeFileAny:data withFullPath:fullpath withDirPath:dirpath];
}

+(BOOL)deleteFile:(NSString*)fullpath
{
    NSError* err = nil;
    return [[NSFileManager defaultManager] removeItemAtPath:fullpath error:&err];
}

+(NSString*)makePathFromApplicationSupportDirectory:(NSString*)path
{
    NSArray* arr = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString* pDocRoot = [arr objectAtIndex:0];
    return [pDocRoot stringByAppendingPathComponent:path];
}

/**
 *  获取 Document 目录，该目录文件在设置共享标记之后可以被 iTunes 读取和写入。REMARK：钱包文件应该存储在该目录（重要）。不能是子目录。
 */
+(NSString*)getDocumentDirectory
{
    NSArray* arr = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* pDocRoot = [arr objectAtIndex:0];
    return pDocRoot;
}

/**
 *  解压zip文件到指定目录
 */
+(BOOL)extractZipFile:(NSString*)zipfilename dstpath:(NSString*)dstpath
{
    char itemname[260] = {0, };
    char databuf[4096] = {0, };
    
    //  打开zip文件
    unzFile zip = unzOpen64([zipfilename UTF8String]);
    if (!zip){
        return NO;
    }
    
    int ret;
    BOOL success = YES;
    NSMutableData* data = [NSMutableData data];
    
    //  循环提取文件
    unz_file_info64 fi;
    for (ret = unzGoToFirstFile(zip); ; ret = unzGoToNextFile(zip)) {
        if (ret == UNZ_END_OF_LIST_OF_FILE){
            break;
        }
        
        if (ret != UNZ_OK){
            success = NO;
            break;
        }
        
        if (unzGetCurrentFileInfo64(zip, &fi, itemname, sizeof(itemname), NULL, 0, NULL, 0) != UNZ_OK)
        {
            success = NO;
            unzCloseCurrentFile(zip);
            break;
        }
        
        BOOL isdir = NO;
        if (itemname[fi.size_filename - 1] == '/' || itemname[fi.size_filename - 1] == '\\'){
            isdir = YES;
        }
        
        //  文件的情况
        if (!isdir){
            //  打开文件
            ret = unzOpenCurrentFile(zip);
            
            //  读取内容
            int bytesRead = 0;
            while ((bytesRead = unzReadCurrentFile(zip, databuf, sizeof(databuf))) > 0)
            {
                [data appendBytes:databuf length:bytesRead];
            }
            
            //  写入文件
            NSString* writepath = [NSString stringWithFormat:@"%@%@", dstpath, [NSString stringWithCString:itemname encoding:NSUTF8StringEncoding]];
            if (![self writeFile:data withFullPath:writepath withDirPath:nil]){
                //  写入失败
                success = NO;
                unzCloseCurrentFile(zip);
                break;
            }
            
            //  reset data buffer
            [data setLength:0];
        }
        
        //  关闭当前文件或目录
        unzCloseCurrentFile(zip);
    }
    
    //  关闭流
    unzClose(zip);
    
    return success;
}

/**
 *  重命名文件（目标文件存在则会覆盖）
 */
+(BOOL)renameFile:(NSString*)srcpath dst:(NSString*)dstpath
{
    //  TODO:未完成 暂时也没用到
//    NSError* error = nil;
//    [[NSFileManager defaultManager] moveItemAtPath:srcpath toPath:dstpath error:&error];
    return NO;
}

//  软件：本地文件最终路径：
//  1、/AppCache/ver/#{curr_version}_filename
//  2、/AppCache/app/filename

/**
 *  直接读取缓存数据
 */
+(NSString*)loaddataByVerStorage:(NSString*)filename
{
    NSData* data = [NSData dataWithContentsOfFile:[self makeFullPathByVerStorage:filename]];
    return [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
}

+(NSString*)loaddataByAppStorage:(NSString*)filename
{
    NSData* data = [NSData dataWithContentsOfFile:[self makeFullPathByAppStorage:filename]];
    return [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
}

/**
 *  写入数据到data的缓存
 */
+(BOOL)saveDataToDataCache:(NSString*)filename data:(NSString*)data base64decode:(BOOL)base64decode
{
    if (!filename || !data)
        return NO;
    
    NSData* rawdata = nil;
    if (base64decode){
        //  解密base64
        rawdata = [[NSData alloc] initWithBase64EncodedString:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
    }else{
        //  string to data
        rawdata = [data dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    //  写入文件
    NSString* fullPathOnCache = [self makeFullPathByVerStorage:[NSString stringWithFormat:@"%@/%@", kAppDataCacheDir, filename]];
    return [self writeFileAny:rawdata withFullPath:fullPathOnCache withDirPath:nil];
}

/**
 *  获取版本依赖文件的完整文件名（路径）
 */
+(NSString*)makeFullPathByVerStorage:(NSString*)filename
{
    NSString* pAppShortVersion = [NativeAppDelegate appShortVersion];
    NSString* path = [NSString stringWithFormat:@"%@/%@/%@_%@", kAppLocalFileNameBase, kAppLocalFileNameByVerStorage, pAppShortVersion, filename];
    return [self makePathFromApplicationSupportDirectory:path];
}

/**
 *  获取app依赖文件的完整文件名（路径）
 */
+(NSString*)makeFullPathByAppStorage:(NSString*)filename
{
    NSString* path = [NSString stringWithFormat:@"%@/%@/%@", kAppLocalFileNameBase, kAppLocalFileNameByAppStorage, filename];
    return [self makePathFromApplicationSupportDirectory:path];
}

/**
 *  获取广告图片所在缓存的完整路径
 */
+(NSString*)makeFullPathByAdStorage:(NSString *)filename
{
    NSString* path = [NSString stringWithFormat:@"%@/%@/%@/%@", kAppLocalFileNameBase, kAppLocalFileNameByAppStorage, kAppAdImageDir, filename];
    return [self makePathFromApplicationSupportDirectory:path];
}

/**
 *  获取钱包bin文件所在目录。
 */
+(NSString*)getAppDirWalletBin
{
    NSString* path = [NSString stringWithFormat:@"%@/%@/%@/", kAppLocalFileNameBase, kAppLocalFileNameByAppStorage, kAppWalletBinFileDir];
    return [self makePathFromApplicationSupportDirectory:path];
}

/**
 *  获取webserver导入目录
 */
+(NSString*)getAppDirWebServerImport
{
    //  REMARK：v1.1版本开始，钱包BIN文件的存放目录改为 Document 目录，该目录可以由 iTunes 进行读取备份等。
    return [self getDocumentDirectory];
}

+ (NSString*)_makeKeyValueString:(NSDictionary*)args
{
    NSMutableArray* pPostArray = [[NSMutableArray alloc] init];
    NSEnumerator* pKeyEnum = [args keyEnumerator];
    NSString* pKey = nil;
    while (pKey = [pKeyEnum nextObject])
    {
        NSString* pValue = (__bridge NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)[NSString stringWithFormat:@"%@", [args objectForKey:pKey]], nil, nil, kCFStringEncodingUTF8);
        [pPostArray addObject:[NSString stringWithFormat:@"%@=%@", pKey, pValue]];
    }
    return [pPostArray componentsJoinedByString:@"&"];
}

+(NSData*)_fetchUrl:(NSString*)pURL args:(NSDictionary*)args
{
    if (!pURL)
        return nil;
    
    NSString* pNewURL = (__bridge NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)pURL, nil, nil, kCFStringEncodingUTF8);
    
    //  GET 参数
    if (args && [args count] > 0){
        id params = [self _makeKeyValueString:args];
        pNewURL = [NSString stringWithFormat:@"%@?%@", pNewURL, params];
    }
    
    NSURL* pNSURL = [NSURL URLWithString:pNewURL];
    return [NSData dataWithContentsOfURL:pNSURL];
}

/**
 *  (private) 同步POST抓取网页。
 */
+(NSData*)_postUrl:(NSString*)pURL data:(NSDictionary*)kvhash body:(NSString*)body_string;
{
    NSString* pPostData;
    NSString* pContentType;
    if (kvhash){
        //  application/x-www-form-urlencoded   连接各参数
        assert(!body_string);
        pPostData = [self _makeKeyValueString:kvhash];
        pContentType = @"application/x-www-form-urlencoded";
    }else{
        //  application/json
        assert(body_string);
        pPostData = body_string;
        pContentType = @"application/json";
    }
    
    //  创建请求 TODO:fowallet default timeout interval config.
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:pURL]
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:60.0f];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[pPostData dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:pContentType forHTTPHeaderField:@"Content-Type"];
    
    //  发起请求
    NSURLResponse* response = nil;
    NSError* error = nil;
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (!data || error)
        return nil;
    return data;
}

/**
 *  获取json请求
 */
+(void)asyncFetchJson:(NSString*)pURL timeout:(NSTimeInterval)seconds completionBlock:(void (^)(id json))completion
{
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:pURL]
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:seconds];
    NSURLSession* session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //  REMARK：dataTaskWithRequest 的 callback 居然不是在主线程执行的，所以这里回调到主线程进行处理。
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!data || error){
                completion(nil);
                return;
            }
            NSError* json_error = nil;
            id resp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&json_error];
            if (json_error || !resp){
                completion(nil);
                return;
            }
            completion(resp);
            return;
        });
    }] resume];
}

+(WsPromise*)_asyncPostUrl:(NSString*)pURL args:(NSDictionary*)kvhash body:(NSString*)body_string
{
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            id data = [self _postUrl:pURL data:kvhash body:body_string];
            if (data){
                //  解析json
                NSError* err = nil;
                id response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
                if (err || !response){
                    NSLog(@"invalid json~");
                    data = nil;
                }else{
                    data = response;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                resolve(data);
            });
        });
    }];
}

/**
 *  异步POST抓取网页。
 */
+(WsPromise*)asyncPostUrl:(NSString*)pURL args:(NSDictionary*)kvhash
{
    return [self _asyncPostUrl:pURL args:kvhash body:nil];
}

+(WsPromise*)asyncPostUrl_jsonBody:(NSString*)pURL args:(NSDictionary*)json
{
    NSError* err = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:json
                                                   options:NSJSONReadingAllowFragments
                                                     error:&err];
    assert(!err && data);
    return [self _asyncPostUrl:pURL args:nil body:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
}

/**
 *  (public) 异步Promise模型 HTTP GET 方法。
 */
+(WsPromise*)asyncFetchUrl:(NSString*)pURL args:(NSDictionary*)args
{
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData* data = [self _fetchUrl:pURL args:args];
            if (data){
                //  解析json
                NSError* err = nil;
                id response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
                if (err || !response){
                    NSLog(@"invalid json~");
                    data = nil;
                }else{
                    data = response;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                resolve(data);
            });
        });
    }];
}

/**
 *  异步的抓取网页，主要用于向服务器发送通知，提交日志等，通过block返回值。
 */
+(void)asyncFetchUrl:(NSString*)pURL completionBlock:(void (^)(NSData*))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData* pData = [self _fetchUrl:pURL args:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(pData);
        });
    });
}

/**
 *  异步下载文件，通过block返回是否成功。带md5验证。
 */
+(void)asyncDownload:(NSString*)pURL verifyMD5:(NSString*)pMD5 fullpath:(NSString*)fullpath completionBlock:(void (^)(BOOL))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL bOk = YES;
        NSData* pData = [self _fetchUrl:pURL args:nil];
        if (pData && pMD5)
        {
            NSString* pCurrMD5 = [self calcNSDataMD5:pData];
            if (![pCurrMD5 isEqualToString:[pMD5 lowercaseString]])
                pData = nil;
        }
        if (pData)
        {
            bOk = [self writeFileAny:pData withFullPath:fullpath withDirPath:nil];
        }
        else
        {
            bOk = NO;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(bOk);
        });
    });
}

+(NSString*)md5:(NSString*)utf8string
{
    return [self calcNSDataMD5:[utf8string dataUsingEncoding:NSUTF8StringEncoding]];
}

+(NSString*)calcFileMD5:(NSString*)pFilePath
{
    NSFileHandle* handle = [NSFileHandle fileHandleForReadingAtPath:pFilePath];
    if (handle == nil)
        return nil;
    
    CC_MD5_CTX md5_ctx;
    CC_MD5_Init(&md5_ctx);
    
    NSData* filedata;
    do {
        filedata = [handle readDataOfLength:CHUNK_SIZE];
        CC_MD5_Update(&md5_ctx, [filedata bytes], (CC_LONG)[filedata length]);
    }
    while([filedata length]);
    
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(result, &md5_ctx);
    
    [handle closeFile];
    
    NSMutableString *hash = [NSMutableString string];
    for(int i=0;i<CC_MD5_DIGEST_LENGTH;i++)
    {
        [hash appendFormat:@"%02x",result[i]];
    }
    return [hash lowercaseString];
}

+(NSString*)calcNSDataMD5:(NSData*)pData
{
    if (!pData)
        return nil;
    
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5_CTX md5_ctx;
    CC_MD5_Init(&md5_ctx);
    CC_MD5_Update(&md5_ctx, [pData bytes], (CC_LONG)[pData length]);
    CC_MD5_Final(result, &md5_ctx);
    
    NSMutableString *hash = [NSMutableString string];
    for(int i=0;i<CC_MD5_DIGEST_LENGTH;i++)
    {
        [hash appendFormat:@"%02x",result[i]];
    }
    return [hash lowercaseString];
}

+(void)showMessage:(NSString*)pMessage
{
    [self showMessage:pMessage withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")];
}

+(void)showMessage:(NSString*)pMessage withTitle:(NSString*)pTitle
{
    [[UIAlertViewManager sharedUIAlertViewManager] showMessage:pMessage withTitle:pTitle completion:^(NSInteger buttonIndex) {
        NSLog(@"msgbox done~");
    }];
}

+(void)showMessageUseHud:(NSString*)pMessage time:(NSInteger)sec parent:(UIView*)pView completionBlock:(void (^)())completion
{
    //  创建对象
    MBProgressHUD* hud = [[MBProgressHUD alloc] initWithView:pView];
    [pView addSubview:hud];
    
    //  如果设置此属性则当前的view置于后台
    hud.dimBackground = YES;
    
    //  设置BlockView颜色
    CGFloat red, green, blue, alpha;
    [[ThemeManager sharedThemeManager].tabBarColor getRed:&red green:&green blue:&blue alpha:&alpha];
    hud.color = [UIColor colorWithRed:red green:green blue:blue alpha:0.97f];
    
    //  设置对话框文字
    hud.labelText = pMessage;
    hud.mode = MBProgressHUDModeText;
    
    //  显示对话框
    [hud showAnimated:YES whileExecutingBlock:^{
        sleep((unsigned int)sec);
    } completionBlock:^{
        [hud removeFromSuperview];
        completion();
    }];
}

/**
 *  比较版本
 *
 *    pVer1大于pVer2返回1，小于返回－1，否则返回0。。
 */
+(NSInteger)compareVersion:(NSString*)pVer1 other:(NSString*)pVer2
{
    NSArray* pVer1Ary = [pVer1 componentsSeparatedByString:@"."];
    NSArray* pVer2Ary = [pVer2 componentsSeparatedByString:@"."];
    
    NSUInteger ver1Count = [pVer1Ary count];
    NSUInteger ver2Count = [pVer2Ary count];
    NSUInteger minCount = MIN(ver1Count, ver2Count);
    
    //  v1 大于 v2 返回正，v1 小于 v2 返回负。
    for (NSUInteger i = 0; i < minCount; ++i)
    {
        NSInteger v1 = [[pVer1Ary objectAtIndex:i] integerValue];
        NSInteger v2 = [[pVer2Ary objectAtIndex:i] integerValue];
        if (v1 > v2) return 1;
        if (v1 < v2) return -1;
    }
    
    return 0;
}

+(NSString*)getDateLocaleString: (NSDate*)date withYear:(BOOL)withYear
{
    if (withYear)
    {
        return [self getDateTimeLocaleString:date withTime:NO];
    }
    else
    {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        //  REMARK：以东8区时间进行显示。
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"Asia/Shanghai"]];
        NSString *localeFormatString = [NSDateFormatter dateFormatFromTemplate:@"dMMM" options:0 locale:dateFormatter.locale];
        dateFormatter.dateFormat = localeFormatString;
        NSString *localizedString = [dateFormatter stringFromDate:date];
        return localizedString;
    }
}

+(NSString*)getDateLocaleString:(NSString *)dateString fmt:(NSString*)fmt withYear:(BOOL)withYear
{
    NSDate *date = [self getDateFromString:dateString fmt:fmt];
    return [self getDateLocaleString:date withYear:withYear];
}

+(NSString*)getDateTimeLocaleString:(NSDate*)date withTime:(BOOL)withTime
{
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = withTime ? kCFDateFormatterShortStyle : kCFDateFormatterNoStyle;
    //  REMARK：以东8区时间进行显示。
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    return [dateFormatter stringFromDate:date];
}

/**
 *  以北京时间格式化日期
 */
+(NSString*)getStringFromDate:(NSDate*)date fmt:(NSString*)fmt
{
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:fmt];
    //  REMARK：以东8区时间进行显示。
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    NSString* str = [dateFormatter stringFromDate:date];
    return str;
}

+(NSString*)getDateTimeLocaleString:(NSDate*)date
{
    return [self getDateTimeLocaleString:date withTime:YES];
}

/**
 *  计算每个月的天数
 */
+ (NSInteger)getDaysOfMonth:(NSInteger)year month:(NSInteger)month
{
    if (month == 2)
    {
        //  闰年：能被4整除、但不能被100整除 或者 能被400整除。
        if (((year % 4) == 0 && (year % 100) != 0) ||
            (year % 400) == 0)
        {
            return 29;
        }
        else
        {
            return 28;
        }
    }
    else if (month == 1 ||
             month == 3 ||
             month == 5 ||
             month == 7 ||
             month == 8 ||
             month == 10 ||
             month == 12)
    {
        return 31;
    }
    else
    {
        return 30;
    }
}

/**
 *  本地通知相关宏定义
 */
#define kAppNotifyModule_UniqueKeyKey   @"__bsppuniquekey" //  本地通知结构体内部user info字典记录通知uniquekey所用的key

/**
 *  (private) 添加本地通知接口
 */
+ (void)addLocalNotify:(NSDate*)date alertBody:(NSString*)alertBody badge:(NSInteger)badge uniquekey:(NSString*)uniquekey soundname:(NSString*)soundname
{
    UILocalNotification* notify = [[UILocalNotification alloc] init];
    notify.alertBody = alertBody;
    notify.fireDate = date;
    notify.soundName = soundname;
    notify.applicationIconBadgeNumber = badge;
    notify.userInfo = [NSDictionary dictionaryWithObject:uniquekey forKey:kAppNotifyModule_UniqueKeyKey];
    [[UIApplication sharedApplication] scheduleLocalNotification:notify];
}

/**
 *  (private) 移除所有本地通知接口
 */
+ (void)removeAllLocalNotify
{
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}

/**
 *  (private) 移除带指定唯一标识符前缀的本地通知接口
 */
+ (void)removeLocalNotifyByHasPrefixUniqueKey:(NSString*)uniquekey
{
    id ary = [[NSArray alloc] initWithArray:[UIApplication sharedApplication].scheduledLocalNotifications];
    if ([ary count] > 0){
        for (UILocalNotification* notify in ary) {
            if (!notify.userInfo){
                continue;
            }
            NSString* key = [notify.userInfo objectForKey:kAppNotifyModule_UniqueKeyKey];
            if (!key || [key isEqualToString:@""]){
                continue;
            }
            if ([key hasPrefix:uniquekey]){
                [[UIApplication sharedApplication] cancelLocalNotification:notify];
            }
        }
    }
}

+ (NSInteger)daysBetweenDate:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime
{
    NSDate *fromDate;
    NSDate *toDate;
    
    NSCalendar *calendar = [NSDate gregorianCalendar];
    
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&fromDate
                 interval:NULL forDate:fromDateTime];
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&toDate
                 interval:NULL forDate:toDateTime];
    
    NSDateComponents *difference = [calendar components:NSCalendarUnitDay
                                               fromDate:fromDate toDate:toDate options:0];
    
    return [difference day];
}

+ (NSInteger)yearsBetweenDate:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime
{
    NSDate *fromDate;
    NSDate *toDate;
    
    NSCalendar *calendar = [NSDate gregorianCalendar];
    
    [calendar rangeOfUnit:NSCalendarUnitYear startDate:&fromDate
                 interval:NULL forDate:fromDateTime];
    [calendar rangeOfUnit:NSCalendarUnitYear startDate:&toDate
                 interval:NULL forDate:toDateTime];
    
    NSDateComponents *difference = [calendar components:NSCalendarUnitYear
                                               fromDate:fromDate toDate:toDate options:0];
    
    return [difference year];
}

/**
 *  从格式化字符串获取 NSDate 对象。
 */
+ (NSDate*)getDateFromString:(NSString*)datestring fmt:(NSString*)fmt
{
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    NSLocale* locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    
    [dateFormat setDateFormat:fmt];
    //  REMARK：所有的时间戳都应该是东8区东，不能用系统时区。
    [dateFormat setTimeZone:[NSTimeZone timeZoneWithName:@"Asia/Shanghai"]];
    [dateFormat setLocale:locale];
    
    NSDate* date = [dateFormat dateFromString:datestring];
    if (!date){
        //  DEBUG
        CLS_LOG(@"dateFromString date is nil, datestring is: %@", datestring);
    }
    
//    [dateFormat release];
//    [locale release];
    return date;
}

+ (NSDate *)dateFromString:(NSString *)dateString
{
    return [self getDateFromString:dateString fmt:@"yyyy-MM-dd"];
}

+ (id)deepClone:(id)obj
{
    if (![NSJSONSerialization isValidJSONObject:obj]){
        NSLog(@"deepClone> invalid json object...");
        return nil;
    }
    NSError* error = nil;
    id data = [NSJSONSerialization dataWithJSONObject:obj options:NSJSONWritingPrettyPrinted error:&error];
    if (error){
        NSLog(@"deepClone> dataWithJSONObject failed: %@", error);
        return nil;
    }
    id newobj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (error){
        NSLog(@"deepClone> JSONObjectWithData failed: %@", error);
        return nil;
    }
    return newobj;
}

+ (float)getHeightForText:(NSString*)text font:(UIFont*)font width:(float)width
{
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    
    NSDictionary *attributes = @{ NSFontAttributeName : font, NSParagraphStyleAttributeName : style };
    
    CGRect rect = [text boundingRectWithSize:(CGSize){width, CGFLOAT_MAX} options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:attributes context:nil];
    return ceilf(rect.size.height);
}

+ (void)adjustHeightForLabel:(UILabel*)label
{
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    
    CGRect newFrame = label.frame;
    newFrame.size.height = [OrgUtils getHeightForText:label.text font:label.font width:label.frame.size.width];
    label.frame = newFrame;
}

+ (NSUInteger)calcGB2312ByteLength:(NSString*)str
{
    NSUInteger len = 0;
    if (str){
        for (NSUInteger i = 0; i < [str length]; ++i) {
            unichar c = [str characterAtIndex:i];
            if (c > 0xFF){
                len += 2;
            }else{
                len += 1;
            }
        }
    }
    return len;
}

/**
 *  把$1 $2之类的占位符替换为 %@
 */
+ (NSString*)replacePlaceholder:(NSString*)src
{
    if (!src){
        return nil;
    }
    NSRegularExpression* regularExpression = [NSRegularExpression regularExpressionWithPattern:@"\\$\\d" options:0 error:nil];
    return [regularExpression stringByReplacingMatchesInString:src options:0 range:NSMakeRange(0, src.length) withTemplate:@"%@"];
}

+ (void)printView:(UIView*)view level:(NSInteger)level
{
    if (!view){
        return;
    }
    NSMutableString* indent = [[NSMutableString alloc] init];
    for (int i = 0; i < level; ++i) {
        [indent appendString:@"\t"];
    }
    NSString* indent2 = [indent copy];
//    [indent release];
    for (UIView* v1 in view.subviews) {
        
        NSLog(@"%@level=%d:%@", indent2, (int)level, v1);
        [self printView:v1 level:level+1];
    }
}

/**
 *  显示 toast 信息，支持设置时间，默认 2s。
 */
+ (void)makeToast:(NSString*)message
{
    [self makeToast:message duration:[CSToastManager defaultDuration] position:[CSToastManager defaultPosition]];
}

+ (void)makeToast:(NSString *)message position:(id)position
{
    [self makeToast:message duration:[CSToastManager defaultDuration] position:position];
}

+ (void)makeToast:(NSString*)message duration:(NSTimeInterval)duration position:(id)position
{
    [CSToastManager setQueueEnabled:NO];
    
    //  设置风格
    CGFloat red, green, blue, alpha;
    [[ThemeManager sharedThemeManager].tabBarColor getRed:&red green:&green blue:&blue alpha:&alpha];
    CSToastStyle* style = [CSToastManager sharedStyle];
    style.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:0.95f];
//    style.cornerRadius = 2;
    style.messageColor = [ThemeManager sharedThemeManager].textColorMain;
    
    //  REMARK：定制 toast 风格
    //    NSString * CSToastPositionTop       = @"CSToastPositionTop";
    //    NSString * CSToastPositionCenter    = @"CSToastPositionCenter";
    //    NSString * CSToastPositionBottom    = @"CSToastPositionBottom";
    [[NativeAppDelegate sharedAppDelegate].window.rootViewController.view makeToast:message
                                                                           duration:duration
                                                                           position:position];
}

+ (id)safeGet:(NSDictionary*)dict key:(NSString*)key defaultValue:(NSObject*)defaultValue
{
    if (!dict || !key)
        return defaultValue;
    id value = [dict objectForKey:key];
    if (!value || [value isKindOfClass:[NSNull class]])
    {
        return defaultValue;
    }
    return value;
}
+ (id)safeGet:(NSDictionary*)dict key:(NSString*)key
{
    return [[self class] safeGet:dict key:key defaultValue:nil];
}
@end
