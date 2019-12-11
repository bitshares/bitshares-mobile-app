//
//  OtcManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "OtcManager.h"
#import "OrgUtils.h"
#import "VCBase.h"
#import "VCOtcMerchantList.h"
#import "VCOtcMcHome.h"

#import "VCOtcUserAuth.h"

static OtcManager *_sharedOtcManager = nil;

@interface OtcManager()
{
    NSString*       _base_api;
    NSDictionary*   _fiat_cny_info;         //  法币信息 TODO:2.9 默认只支持一种
    NSArray*        _asset_list_digital;    //  支持的数字资产列表
}
@end

@implementation OtcManager

@synthesize asset_list_digital = _asset_list_digital;

+(OtcManager *)sharedOtcManager
{
    @synchronized(self)
    {
        if(!_sharedOtcManager)
        {
            _sharedOtcManager = [[OtcManager alloc] init];
        }
        return _sharedOtcManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        //  TODO:2.9
        _base_api = @"http://otc-api.gdex.vip";
        _fiat_cny_info  = nil;
        _asset_list_digital = nil;
    }
    return self;
}

- (void)dealloc
{
    _base_api = nil;
    _fiat_cny_info  = nil;
    self.asset_list_digital = nil;
}

/*
 *  (public) 解析 OTC 服务器返回的时间字符串，格式：2019-11-26T13:29:51.000+0000。
 */
+ (NSTimeInterval)parseTime:(NSString*)time
{
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
    [dateFormat setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    NSDate* date = [dateFormat dateFromString:time];
    return ceil([date timeIntervalSince1970]);
}

/*
 *  格式化：场外交易订单列表日期显示格式。REMARK：以当前时区格式化，北京时间当前时区会+8。
 */
+ (NSString*)fmtOrderListTime:(NSString*)time
{
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"MM-dd HH:mm"];
    return [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970:[self parseTime:time]]];
}

/*
 *  格式化：场外交易订单详情日期显示格式。REMARK：以当前时区格式化，北京时间当前时区会+8。
 */
+ (NSString*)fmtOrderDetailTime:(NSString*)time
{
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    return [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970:[self parseTime:time]]];
}

/*
 *  格式化：格式化商家加入日期格式。REMARK：以当前时区格式化，北京时间当前时区会+8。
 */
+ (NSString*)fmtMerchantTime:(NSString*)time
{
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd"];
    return [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970:[self parseTime:time]]];
}

/*
 *  格式化：场外交易订单倒计时时间。
 */
+ (NSString*)fmtPaymentExpireTime:(NSInteger)left_ts
{
    assert(left_ts > 0);
    
    int min = (int)(left_ts / 60);
    int sec = (int)(left_ts % 60);
    
    return [NSString stringWithFormat:@"%02d:%02d", min, sec];
}

/*
 *  (public) 辅助 - 获取收款方式名字图标等。
 */
+ (NSDictionary*)auxGenPaymentMethodInfos:(NSString*)account type:(id)type bankname:(NSString*)bankname
{
    assert(account);
    assert(type);
    
    NSString* name = nil;
    NSString* icon = nil;
    NSString* short_account = account;
    
    switch ([type integerValue]) {
        case eopmt_alipay:
        {
            name = NSLocalizedString(@"kOtcAdPmNameAlipay", @"支付宝");
            icon = @"iconPmAlipay";
        }
            break;
        case eopmt_bankcard:
        {
            icon = @"iconPmBankCard";
            name = bankname;
            if (!name || [bankname isEqualToString:@""]) {
                name = NSLocalizedString(@"kOtcAdPmNameBankCard", @"银行卡");
            }
            NSString* card_no = [account stringByReplacingOccurrencesOfString:@" " withString:@""];
            short_account = [card_no substringFromIndex:MAX((NSInteger)card_no.length - 4, 0)];
        }
            break;
        case eopmt_wechatpay:
        {
            icon = @"iconPmWechat";
            name = NSLocalizedString(@"kOtcAdPmNameWechatPay", @"微信支付");
        }
            break;
        default:
            break;
    }
    if (!name) {
        name = [NSString stringWithFormat:NSLocalizedString(@"kOtcAdPmUnknownType", @"未知收款方式%@"), type];
    }
    if (!icon) {
        icon = @"iconPmBankCard";//TODO:2.9 default  icon
    }
    return @{@"name":name, @"icon":icon, @"name_with_short_account":[NSString stringWithFormat:@"%@(%@)", name, short_account]};
}

/*
 *  (public) 辅助 - 根据订单当前状态获取主状态、状态描述、以及可操作按钮等信息。
 */
+ (NSDictionary*)auxGenUserOrderStatusAndActions:(id)order
{
    assert(order);
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    BOOL bUserSell = [[order objectForKey:@"type"] integerValue] == eoot_data_sell;
    NSInteger status = [[order objectForKey:@"status"] integerValue];
    NSString* status_main = nil;
    NSString* status_desc = nil;
    NSMutableArray* actions = [NSMutableArray array];
    BOOL showRemark = NO;
    BOOL pending = YES;
    //  TODO:2.9 状态描述待细化。!!!!
    if (bUserSell) {
        //  -- 用户卖币提现
        switch (status) {
            //  正常流程
            case eoops_new:
            {
                status_main = @"待转币";               //  已下单(待转币)     正常情况下单自动转币、转币操作需二次确认
                status_desc = @"您已成功下单，请转币。";
                //  按钮：联系客服 + 立即转币
                [actions addObject:@{@"type":@(eooot_contact_customer_service), @"color":theme.textColorGray}];
                [actions addObject:@{@"type":@(eooot_transfer), @"color":theme.textColorHighlight}];
            }
                break;
            case eoops_already_transferred:
            {
                status_main = @"已转币";               //  已转币(待处理)
                status_desc = @"您已转币，正在等待区块确认。";
            }
                break;
            case eoops_already_confirmed:
            {
                status_main = @"待收款";               //  区块已确认(待收款)
                status_desc = @"区块已确认转币，等待商家付款。";
            }
                break;
            case eoops_already_paid:
            {
                status_main = @"请放行";               // 商家已付款(请放行) 申诉 + 确认收款(放行操作需二次确认)
                status_desc = @"请查收对方付款，未收到请勿放行。";
                //  按钮：联系客服 + 放行XXX资产
                [actions addObject:@{@"type":@(eooot_contact_customer_service), @"color":theme.textColorGray}];
                [actions addObject:@{@"type":@(eooot_confirm_received_money), @"color":theme.textColorHighlight}];
            }
                break;
            case eoops_completed:
            {
                status_main = @"已完成";
                status_desc = @"订单已完成。";
                pending = NO;
            }
                break;
            //  异常流程
            case eoops_chain_failed:
            {
                status_main = @"异常中";
                status_desc = @"区块确认异常，请联系客服。";
                //  按钮：联系客服
                [actions addObject:@{@"type":@(eooot_contact_customer_service), @"color":theme.textColorGray}];
            }
                break;
            case eoops_return_assets:
            {
                status_main = @"退币中";
                status_desc = @"商家无法接单，退币处理中。";
            }
                break;
            case eoops_cancelled:
            {
                status_main = @"已取消";
                status_desc = @"订单已取消。";
                pending = NO;
            }
                break;
            default:
                break;
        }
    } else {
        //  -- 用户充值买币
        switch (status) {
            //  正常流程
            case eoops_new:
            {
                status_main = @"待付款";       // 已下单(待付款)     取消 + 确认付款
                status_desc = @"请尽快付款给卖家。";
                showRemark = YES;
                //  按钮：取消订单 + 确认付款
                [actions addObject:@{@"type":@(eooot_cancel_order), @"color":theme.textColorGray}];
                [actions addObject:@{@"type":@(eooot_confirm_paid), @"color":theme.textColorHighlight}];
            }
                break;
            case eoops_already_paid:
            {
                status_main = @"待收币";       // 已付款(待收币)
                status_desc = @"您已付款，请等待商家确认并放币。";
            }
                break;
            case eoops_already_transferred:
            {
                status_main = @"已转币";       //  已转币
                status_desc = @"商家已转币，正在等待区块确认。";
            }
                break;
            case eoops_already_confirmed:
            {
                status_main = @"已收币";       //  已收币 REMARK：这是中间状态，会自动跳转到已完成。
                status_desc = @"商家转币已确认，请查收。";
                break;
            }
            case eoops_completed:
            {
                status_main = @"已完成";
                status_desc = @"订单已完成。";
                pending = NO;
            }
                break;
            //  异常流程
            case eoops_refunded:
            {
                status_main = @"已退款";
                status_desc = @"商家无法接单，已退款，请查收退款。";
                //  按钮：联系客服 + 我已收到退款（取消订单）
                [actions addObject:@{@"type":@(eooot_contact_customer_service), @"color":theme.textColorGray}];
                [actions addObject:@{@"type":@(eooot_confirm_received_refunded), @"color":theme.textColorHighlight}];
            }
                break;
            case eoops_chain_failed:
            {
                status_main = @"异常中";
                status_desc = @"区块确认异常，请联系客服。";
                //  按钮：联系客服
                [actions addObject:@{@"type":@(eooot_contact_customer_service), @"color":theme.textColorGray}];
            }
                break;
            case eoops_cancelled:
            {
                status_main = @"已取消";
                status_desc = @"订单已取消。";
                pending = NO;
            }
                break;
            default:
                break;
        }
    }
    if (!status_main) {
        status_main = [NSString stringWithFormat:@"未知状态 %@", @(status)];
    }
    if (!status_desc) {
        status_desc = [NSString stringWithFormat:@"未知状态 %@", @(status)];
    }
    
    //  返回数据
    return @{@"main":status_main, @"desc":status_desc,
             @"actions":actions, @"sell":@(bUserSell),
             @"phone":order[@"phone"] ?: @"",
             @"show_remark":@(showRemark), @"pending":@(pending)};
}

/*
 *  (public) 当前账号名
 */
- (NSString*)getCurrentBtsAccount
{
    assert([[WalletManager sharedWalletManager] isWalletExist]);
    return [[WalletManager sharedWalletManager] getWalletAccountName];
}

/*
 *  (public) 获取当前法币信息
 */
- (NSDictionary*)getFiatCnyInfo
{
    if (_fiat_cny_info) {
        //{
        //    assetAlias = "\U4eba\U6c11\U5e01";
        //    assetId = "1.0.1";
        //    assetPrecision = 2;
        //    btsId = "<null>";
        //    assetSymbol = CNY;
        //    type = 1;
        //}
        id symbol = _fiat_cny_info[@"assetSymbol"];
        id precision = _fiat_cny_info[@"assetPrecision"];
        id assetId = _fiat_cny_info[@"assetId"];
        //  TODO:2.9 short_symbol
        return @{@"assetSymbol":symbol, @"precision":precision, @"id":assetId, @"short_symbol":@"¥", @"name":_fiat_cny_info[@"assetAlias"]};
    } else {
        assert(false);
        return nil;
    }
}

/*
 *  (public) 是否支持指定资产判断
 */
- (BOOL)isSupportDigital:(NSString*)asset_name
{
    assert(asset_name);
    if (self.asset_list_digital && [self.asset_list_digital count] > 0) {
        for (id item in self.asset_list_digital) {
            if ([[item objectForKey:@"assetSymbol"] isEqualToString:asset_name]) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  (public) 获取资产信息。OTC运营方配置的，非链上数据。
 */
- (NSDictionary*)getAssetInfo:(NSString*)asset_name
{
    assert(asset_name);
    if (self.asset_list_digital && [self.asset_list_digital count] > 0) {
        for (id item in self.asset_list_digital) {
            if ([[item objectForKey:@"assetSymbol"] isEqualToString:asset_name]) {
                return item;
            }
        }
    }
    assert(false);
    //  not reached
    return nil;
}

/*
 *  (public) 转到OTC界面，会自动初始化必要信息。
 */
- (void)gotoOtc:(VCBase*)owner asset_name:(NSString*)asset_name ad_type:(EOtcAdType)ad_type
{
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    assert([walletMgr isWalletExist]);
    
    if ([WalletManager isMultiSignPermission:[walletMgr getWalletAccountInfo][@"account"][@"active"]]) {
        //  TODO:2.9
        [OrgUtils makeToast:@"多签账号不支持场外交易。"];
        return;
    }
    
    [owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    WsPromise* p1 = [self queryAssetList:eoat_fiat];
    WsPromise* p2 = [self queryAssetList:eoat_digital];
    [[[WsPromise all:@[p1, p2]] then:^id(id data_array) {
        [owner hideBlockView];
        id fiat_data = [data_array objectAtIndex:0];
        id asset_data = [data_array objectAtIndex:1];
        
        //  获取法币信息
        _fiat_cny_info = nil;
        id asset_list_fiat = [fiat_data objectForKey:@"data"];
        if (asset_list_fiat && [asset_list_fiat count] > 0) {
            for (id fiat_info in asset_list_fiat) {
                //  TODO:2.9 固定fiat CNY
                if ([[fiat_info objectForKey:@"assetSymbol"] isEqualToString:@"CNY"]) {
                    _fiat_cny_info = fiat_info;
                    break;
                }
            }
        }
        if (!_fiat_cny_info) {
            //  TODO:2.9 lang
            [OrgUtils makeToast:@"场外交易不支持CNY法币，请稍后再试。"];
            return nil;
        }
        //  获取数字货币信息
        self.asset_list_digital = [asset_data objectForKey:@"data"];
        if (!self.asset_list_digital || [self.asset_list_digital count] <= 0) {
            //  TODO:2.9 lang
            [OrgUtils makeToast:@"场外交易暂不支持任何数字资产，请稍后再试。"];
            return nil;
        }
        //  是否支持判断
        if (![self isSupportDigital:asset_name]) {
            //  TODO:2.9 lang
            [OrgUtils makeToast:[NSString stringWithFormat:@"场外交易暂时不支持 %@ 资产，请稍后再试。", asset_name]];
            return nil;
        }
        
        //  转到场外交易界面
        VCBase* vc = [[VCOtcMerchantListPages alloc] initWithAssetName:asset_name ad_type:ad_type];
        vc.title = @"";
        [owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        return nil;
    }] catch:^id(id error) {
        [owner hideBlockView];
        [self showOtcError:error];
        return nil;
    }];
}

- (void)_guardUserIdVerified:(VCBase*)owner
                   auto_hide:(BOOL)auto_hide
           askForIdVerifyMsg:(NSString*)askForIdVerifyMsg
               first_request:(BOOL)first_request
                    callback:(void (^)(id auth_info))verifyed_callback
{
    [owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[self queryIdVerify:[self getCurrentBtsAccount]] then:^id(id responsed) {
        if ([self isIdVerifyed:responsed]) {
            if (auto_hide) {
                [owner hideBlockView];
            }
            //  已认证：返回认证后数据。
            verifyed_callback([responsed objectForKey:@"data"]);
        } else {
            [owner hideBlockView];
            //  未认证：询问认证 or 直接转认证界面
            if (askForIdVerifyMsg) {
                [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:askForIdVerifyMsg
                                                                       withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                                      completion:^(NSInteger buttonIndex)
                 {
                     if (buttonIndex == 1)
                     {
                         VCBase* vc = [[VCOtcUserAuth alloc] init];
                         [owner pushViewController:vc
                                          vctitle:NSLocalizedString(@"kVcTitleOtcUserAuth", @"身份认证")
                                        backtitle:kVcDefaultBackTitleName];
                     }
                 }];
            } else {
                VCBase* vc = [[VCOtcUserAuth alloc] init];
                [owner pushViewController:vc
                                 vctitle:NSLocalizedString(@"kVcTitleOtcUserAuth", @"身份认证")
                               backtitle:kVcDefaultBackTitleName];
            }
        }
        return nil;
    }] catch:^id(id error) {
        [owner hideBlockView];
        if (first_request) {
            [self showOtcError:error not_login_callback:^{
                //  处理登录
                [self handleOtcUserLogin:owner login_callback:^{
                    //  query id verify again
                    [self _guardUserIdVerified:owner
                                     auto_hide:auto_hide
                             askForIdVerifyMsg:askForIdVerifyMsg
                                 first_request:NO
                                      callback:verifyed_callback];
                }];
            }];
        } else {
            [self showOtcError:error];
        }
        return nil;
    }];
}

/*
 *  (public) 确保已经进行认证认证。
 */
- (void)guardUserIdVerified:(VCBase*)owner
                  auto_hide:(BOOL)auto_hide
          askForIdVerifyMsg:(NSString*)askForIdVerifyMsg
                   callback:(void (^)(id auth_info))verifyed_callback
{
    assert(owner);
    assert(verifyed_callback);
    [self _guardUserIdVerified:owner
                     auto_hide:auto_hide
             askForIdVerifyMsg:askForIdVerifyMsg
                 first_request:YES
                      callback:verifyed_callback];
}

/*
 *  (public) 请求私钥授权登录。
 */
- (void)handleOtcUserLogin:(VCBase*)owner login_callback:(void (^)())login_callback
{
    assert(owner);
    assert(login_callback);
    [owner GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            [owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            NSString* account_name = [self getCurrentBtsAccount];
            [[[self login:account_name] then:^id(id login_responsed) {
                [owner hideBlockView];
                NSString* token = [login_responsed objectForKey:@"data"];
                if (token && [token isKindOfClass:[NSString class]] && ![token isEqualToString:@""]) {
                    [self _saveUserTokenCookie:account_name token:token];
                    login_callback();
                } else {
                    [self showOtcError:nil];
                }
                return nil;
            }] catch:^id(id error) {
                [owner hideBlockView];
                [self showOtcError:error];
                return nil;
            }];
        }
    }];
}

/*
 *  (public) 处理用户注销账号。需要清理token等信息。
 */
- (void)processLogout
{
    if ([[WalletManager sharedWalletManager] isWalletExist]) {
        [self _delUserTokenCookie:[self getCurrentBtsAccount]];
    }
}

/*
 *  (public) 是否是未登录错误判断。
 */
- (BOOL)isOtcUserNotLoginError:(id)error
{
    if (error && [error isKindOfClass:[WsPromiseException class]]){
        WsPromiseException* excp = (WsPromiseException*)error;
        id userInfo = excp.userInfo;
        if (userInfo) {
            id otcerror = [userInfo objectForKey:@"otcerror"];
            if (otcerror) {
                NSInteger errcode = [[otcerror objectForKey:@"code"] integerValue];
                if (errcode == eoerr_not_login) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

/*
 *  (public) 显示OTC的错误信息。
 */
- (void)showOtcError:(id)error
{
    [self showOtcError:error not_login_callback:nil];
}

- (void)showOtcError:(id)error not_login_callback:(void (^)())not_login_callback
{
    NSString* errmsg = nil;
    if (error && [error isKindOfClass:[WsPromiseException class]]){
        WsPromiseException* excp = (WsPromiseException*)error;
        id userInfo = excp.userInfo;
        if (userInfo) {
            id otcerror = [userInfo objectForKey:@"otcerror"];
            if (otcerror) {
                //  异常中包含 otcerror 的情况
                NSInteger errcode = [[otcerror objectForKey:@"code"] integerValue];
                if (errcode == eoerr_not_login && not_login_callback) {
                    not_login_callback();
                    return;
                } else {
                    //  TODO:2.9 error code table 部分消息特化处理。
                    switch (errcode) {
                        case eoerr_too_often:
                            errmsg = @"请求太频繁，请稍后再试。";
                            break;
                        case eoerr_not_login:
                            errmsg = @"请退出场外交易界面重新登录。";
                            break;
                        default:
                            {
                                //  默认错误消息处理
                                NSString* tmpmsg = [otcerror objectForKey:@"message"];
                                if ([tmpmsg isKindOfClass:[NSString class]] && ![tmpmsg isEqualToString:@""]) {
                                    //  显示 code 和 message
                                    errmsg = [NSString stringWithFormat:@"%@", otcerror];
                                } else {
                                    //  仅显示 code
                                    errmsg = [NSString stringWithFormat:@"服务器或网络异常，请稍后再试。错误代码：%@", @(errcode)];//TODO:2.9 lang
                                }
                            }
                            break;
                    }

                }
            }
        }
        if (!errmsg) {
            errmsg = excp.reason;
        }
    }
    if (!errmsg || [errmsg isEqualToString:@""]) {
        //  没有任何错误信息的情况
        errmsg = @"服务器或网络异常，请稍后再试。";//TODO:2.9
    }
    [OrgUtils makeToast:errmsg];
}

/*
 *  (public) 辅助方法 - 是否已认证判断
 */
- (BOOL)isIdVerifyed:(id)responsed
{
    id data = [responsed objectForKey:@"data"];
    if (!data) {
        return NO;
    }
    NSInteger iIdVerify = [[data objectForKey:@"isIdcard"] integerValue];
    if (iIdVerify == eovs_kyc1 || iIdVerify == eovs_kyc2 || iIdVerify == eovs_kyc3) {
        return YES;
    }
    return NO;
}

/*
 *  (public) API - 查询OTC用户身份认证信息。
 *  认证：TOKEN 方式
 *  bts_account_name    - BTS账号名
 */
- (WsPromise*)queryIdVerify:(NSString*)bts_account_name
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/user/queryIdVerify"];
    //  TODO:2.9服务器暂时没验证签名？
//    id headers = @{
//        @"btsAccount":bts_account_name,
//        @"dataVerify":@"",//TODO:2.9
//        @"dataVerifyType":@"",//TODO:2.9
//        @"holderVerify":@"",//TODO:2.9
//    };
    return [self _queryApiCore:url args:@{@"btsAccount":bts_account_name} headers:nil auth_flag:eoaf_token];
}

/*
 *  (public) 请求身份认证
 */
- (WsPromise*)idVerify:(id)args
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/user/idcardVerify"];
    return [self _queryApiCore:url args:args headers:nil];
}

/*
 *  (public) 创建订单
 */
- (WsPromise*)createUserOrder:(NSString*)bts_account_name
                        ad_id:(NSString*)ad_id
                         type:(EOtcAdType)ad_type
                        price:(NSString*)price
                        total:(NSString*)total
{
//    NSString* fiat_symbol = [[self getFiatCnyInfo] objectForKey:@"short_symbol"];
//    assert(fiat_symbol);
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/user/order/set"];
    id args = @{
        @"adId":ad_id,
        @"adType":@(ad_type),
        @"btsAccount":bts_account_name,
        @"legalCurrency":@"￥",   //  !!!!! TODO:2.9 暂时只支持这一个！汗
        @"price":price,
        @"totalAmount":total
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_sign];
}

/*
 *  (public) API - 查询用户订单列表
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryUserOrders:(NSString*)bts_account_name
                         type:(EOtcOrderType)type
                       status:(EOtcOrderStatus)status
                         page:(NSInteger)page
                    page_size:(NSInteger)page_size
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/user/order/list"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"orderType":@(type),
        @"status":@(status),
        @"page":@(page),
        @"pageSize":@(page_size)
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_token];
}

/*
 *  (public) API - 查询订单详情
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryUserOrderDetails:(NSString*)bts_account_name order_id:(NSString*)order_id
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/user/order/details"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"orderId":order_id,
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_token];
}

/*
 *  (public) 更新订单
 */
- (WsPromise*)updateUserOrder:(NSString*)bts_account_name
                     order_id:(NSString*)order_id
                   payAccount:(NSString*)payAccount
                   payChannel:(id)payChannel
                         type:(EOtcOrderUpdateType)type
{
    assert(bts_account_name);
    assert(order_id);
    
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/user/order/update"];
    
    id args = [NSMutableDictionary dictionary];
    [args setObject:bts_account_name forKey:@"btsAccount"];
    [args setObject:order_id forKey:@"orderId"];
    [args setObject:@(type) forKey:@"type"];
    //  有的状态不需要这些参数。
    if (payAccount) {
        [args setObject:payAccount forKey:@"payAccount"];
    }
    if (payChannel) {
        [args setObject:payChannel forKey:@"paymentChannel"];
    }
    
    return [self _queryApiCore:url args:[args copy] headers:nil];
}

/*
 *  (public) API - 查询用户收款方式
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryPaymentMethods:(NSString*)bts_account_name
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/payMethod/query"];
    id args = @{
        @"btsAccount":bts_account_name,
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_token];
}

- (WsPromise*)addPaymentMethods:(id)args
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/payMethod/add"];
    return [self _queryApiCore:url args:args headers:nil];
}

- (WsPromise*)delPaymentMethods:(NSString*)bts_account_name pmid:(id)pmid
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/payMethod/del"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"id":pmid,
    };
    return [self _queryApiCore:url args:args headers:nil];
}

- (WsPromise*)editPaymentMethods:(NSString*)bts_account_name new_status:(EOtcPaymentMethodStatus)new_status pmid:(id)pmid
{
    assert(bts_account_name);
    assert(pmid);
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/payMethod/edit"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"id":pmid,
        @"status":@(new_status)
    };
    return [self _queryApiCore:url args:args headers:nil];
}

/*
 *  (public) 上传二维码图片。
 */
- (WsPromise*)uploadQrCode:(NSString*)bts_account_name filename:(NSString*)filename data:(NSData*)data
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/oss/upload"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"fileName":filename,
    };
    return [self _handle_otc_server_response:[OrgUtils asyncUploadBinaryData:url data:data key:@"multipartFile" filename:filename args:args]];
}

/*
 *  (public) 获取二维码图片流。
 */
- (WsPromise*)queryQrCode:(NSString*)bts_account_name filename:(NSString*)filename
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/oss/query"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"fileName":filename,
    };
    return [self _queryApiCore:url args:args headers:nil as_json:NO auth_flag:eoaf_none];
}

/*
 *  (public) API - 查询OTC支持的数字资产列表（bitCNY、bitUSD、USDT等）
 *  认证：无
 *  asset_type  - 资产类型 默认值：eoat_digital
 */
- (WsPromise*)queryAssetList
{
    return [self queryAssetList:eoat_digital];
}

- (WsPromise*)queryAssetList:(EOtcAssetType)asset_type
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/asset/getList"];
    return [self _queryApiCore:url args:@{@"type":@(asset_type)} headers:nil];
}

/*
 *  (public) API - 查询OTC商家广告列表。
 *  认证：无
 *  ad_status   - 广告状态 默认值：eoads_online
 *  ad_type     - 状态类型
 *  asset_name  - OTC数字资产名字（CNY、USD、GDEX.USDT等）
 *  page        - 页号
 *  page_size   - 每页数量
 */
- (WsPromise*)queryAdList:(EOtcAdType)ad_type asset_name:(NSString*)asset_name page:(NSInteger)page page_size:(NSInteger)page_size
{
    return [self queryAdList:eoads_online type:ad_type asset_name:asset_name page:page page_size:page_size];
}

- (WsPromise*)queryAdList:(EOtcAdStatus)ad_status type:(EOtcAdType)ad_type asset_name:(NSString*)asset_name
                     page:(NSInteger)page page_size:(NSInteger)page_size
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/ad/list"];
    id args = @{
        @"adStatus":@(ad_status),
        @"adType":@(ad_type),
        @"assetSymbol":asset_name,
        @"page":@(page),
        @"pageSize":@(page_size)
    };
    return [self _queryApiCore:url args:args headers:nil];
}

///*
// *  (public) 查询广告详情。
// */
//- (WsPromise*)queryAdDetails:(NSString*)ad_id
//{
//    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/ad/detail"];
//    id args = @{
//        @"adId":ad_id,
//    };
//    return [self _queryApiCore:url args:args headers:nil];
//}

/*
 *  (public) API - 锁定价格
 *  认证：TOKEN 方式
 */
- (WsPromise*)lockPrice:(NSString*)bts_account_name
                  ad_id:(NSString*)ad_id
                   type:(EOtcAdType)ad_type
           asset_symbol:(NSString*)asset_symbol
                  price:(NSString*)price
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/order/price/lock/set"];
    id args = @{
        @"adId":ad_id,
        @"adType":@(ad_type),
        @"btsAccount":bts_account_name,
        @"assetSymbol":asset_symbol,//@"￥",//TODO:2.9
        @"price":price
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_token];
}

/*
 *  (public) 发送短信
 */
- (WsPromise*)sendSmsCode:(NSString*)bts_account_name phone:(NSString*)phone_number type:(EOtcSmsType)type
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/sms/send"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"phoneNum":phone_number,
        @"type":@(type)
    };
    return [self _queryApiCore:url args:args headers:nil];
}

/*
 *  (public) API - 登录。部分API接口需要传递登录过的token字段。
 *  认证：SIGN 方式
 */
- (WsPromise*)login:(NSString*)bts_account_name
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/user/login"];
    id args = @{
        @"btsAccount":bts_account_name,
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_sign];
}

/*
 *  (private) 执行OTC网络请求。
 *  as_json     - 是否返回 json 格式，否则返回原始数据流。
 */
- (WsPromise*)_queryApiCore:(NSString*)url args:(id)args headers:(id)headers
{
    return [self _queryApiCore:url args:args headers:headers as_json:YES auth_flag:eoaf_none];
}

- (WsPromise*)_queryApiCore:(NSString*)url args:(id)args headers:(id)headers auth_flag:(EOtcAuthFlag)auth_flag
{
    return [self _queryApiCore:url args:args headers:headers as_json:YES auth_flag:auth_flag];
}

- (WsPromise*)_queryApiCore:(NSString*)url args:(id)args headers:(id)headers as_json:(BOOL)as_json auth_flag:(EOtcAuthFlag)auth_flag
{
    //  认证：签名 or token
    if (auth_flag != eoaf_none) {
        //  计算签名 先获取毫秒时间戳
        id timestamp = [NSString stringWithFormat:@"%@", @((uint64_t)([[NSDate date] timeIntervalSince1970] * 1000))];
        NSString* auth_key;
        NSString* auth_value;
        if (auth_flag == eoaf_sign) {
            auth_key = @"sign";
            auth_value = [self _sign:timestamp args:args];
        } else {
            assert(auth_flag == eoaf_token);
            auth_key = @"token";
            auth_value = [self _loadUserTokenCookie:[self getCurrentBtsAccount]];
        }
        //  合并请求header
        id new_headers = headers ? [headers mutableCopy] : [NSMutableDictionary dictionary];
        [new_headers setObject:timestamp forKey:@"timestamp"];
        if (auth_value) {
            [new_headers setObject:auth_value forKey:auth_key];
        }
        //  更新header
        headers = [new_headers copy];
    }
    
    //  执行请求
    WsPromise* request_promise = [OrgUtils asyncPostUrl_jsonBody:url args:args headers:headers as_json:as_json];
    if (as_json) {
        //  REMARK：json格式需要判断返回值
        return [self _handle_otc_server_response:request_promise];
    } else {
        //  文件流直接返回。
        return request_promise;
    }
}

/*
 *  (private) 处理返回值。
 *  request_promise - 实际的网络请求。
 */
- (WsPromise*)_handle_otc_server_response:(WsPromise*)request_promise
{
    assert(request_promise);
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [[request_promise then:^id(id responsed) {
            //  TODO:2.9 lang
            if (!responsed || ![responsed isKindOfClass:[NSDictionary class]]) {
                reject(@"服务器或网络异常，请稍后再试。");
                return nil;
            }
            NSInteger code = [[responsed objectForKey:@"code"] integerValue];
            if (code != eoerr_ok) {
                reject(@{@"otcerror":@{@"code":@(code), @"message":[responsed objectForKey:@"message"] ?: @""}});
            } else {
                resolve(responsed);
            }
            return nil;
        }] catch:^id(id error) {
            reject(@"服务器或网络异常，请稍后再试。");
            return nil;
        }];
    }];
}

/*
 *  (private) token信息管理
 */
- (NSString*)_genUserTokenCookieName:(NSString*)bts_account_name
{
    assert(bts_account_name);
    //  TODO:2.9 token key config
    return [NSString stringWithFormat:@"_bts_otc_token_%@", bts_account_name];
}

- (NSString*)_loadUserTokenCookie:(NSString*)bts_account_name
{
    return (NSString*)[[AppCacheManager sharedAppCacheManager] getPref:[self _genUserTokenCookieName:bts_account_name]];
}

- (void)_delUserTokenCookie:(NSString*)bts_account_name
{
    [[[AppCacheManager sharedAppCacheManager] deletePref:[self _genUserTokenCookieName:bts_account_name]] saveCacheToFile];
}

- (void)_saveUserTokenCookie:(NSString*)bts_account_name token:(NSString*)token
{
    if (token) {
        [[[AppCacheManager sharedAppCacheManager] setPref:[self _genUserTokenCookieName:bts_account_name] value:token] saveCacheToFile];
    }
}

/*
 *  (private) 生成待签名之前的完整字符串。
 */
- (NSString*)_gen_sign_string:(NSDictionary*)args
{
    NSArray* sortedKeys = [[args allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    NSMutableArray* pArray = [[NSMutableArray alloc] init];
    for (NSString* pKey in sortedKeys) {
        //  TODO:2.9 url encode??
        //  NSString* pValue = (__bridge NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)[NSString stringWithFormat:@"%@", [args objectForKey:pKey]], nil, nil, kCFStringEncodingUTF8);
        NSString* pValue = [args objectForKey:pKey];
        [pArray addObject:[NSString stringWithFormat:@"%@=%@", pKey, pValue]];
    }
    return [pArray componentsJoinedByString:@"&"];
}

/*
 *  (private) 执行签名。钱包需要先解锁。
 */
- (NSString*)_sign:(id)timestamp args:(id)args
{
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    assert(![walletMgr isLocked]);
    
    //  获取待签名字符串
    id sign_args = args ? [args mutableCopy] : [NSMutableDictionary dictionary];
    [sign_args setObject:timestamp forKey:@"timestamp"];
    NSString* sign_str = [self _gen_sign_string:sign_args];
    
    //  TODO:2.9 实际签名数据是否加上chain id
    NSData* sign_data = [sign_str dataUsingEncoding:NSUTF8StringEncoding];
    
    //  TODO:2.9 不支持任何多签。必须单key 100%权限。active。
    id active_permission = [[[walletMgr getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"active"];
    id sign_keys = [walletMgr getSignKeys:active_permission];
    assert([sign_keys count] == 1);
    id signs = [walletMgr signTransaction:sign_data signKeys:sign_keys];
    if (!signs) {
        //  签名失败
        return nil;
    }
    
    return [[signs firstObject] hex_encode];
}

#pragma mark- for merchant

- (void)gotoOtcMerchantHome:(VCBase*)owner
{
    //  TODO:3.0
    
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    assert([walletMgr isWalletExist]);
    
    [owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  TODO:3.0 unlock sign
    [[[self merchantProgress:[self getCurrentBtsAccount]] then:^id(id responsed) {
        
        //{
        //    code = 0;
        //    data =     {
        //        bakAccount = "<null>";
        //        btsAccount = "<null>";
        //        level = "<null>";
        //        nickname = "<null>";
        //        status = 0;
        //    };
        //    message = success;
        //}
        id progress_info = [responsed objectForKey:@"data"];
        NSInteger progress_status = [[progress_info objectForKey:@"status"] integerValue];
        if (progress_status == eomp_default) {
            [owner hideBlockView];
            //  TODO:3.0 未申请
            [OrgUtils makeToast:@"去申请界面。"];
            return nil;
        } else {
            if (progress_status == eomp_approved || progress_status == eomp_activated) {
                //  已同意：查询商家详情
                return [[self merchantDetail:[self getCurrentBtsAccount]] then:^id(id merchant_detail_responsed) {
                    [owner hideBlockView];
                    VCBase* vc = [[VCOtcMcHome alloc] initWithProgressInfo:progress_info
                                                            merchantDetail:[merchant_detail_responsed objectForKey:@"data"]];
                    [owner pushViewController:vc vctitle:@"商家信息" backtitle:kVcDefaultBackTitleName];
                    return nil;
                }];
            } else {
                //  申请中 or 已拒绝
                [owner hideBlockView];
                VCBase* vc = [[VCOtcMcHome alloc] initWithProgressInfo:progress_info merchantDetail:nil];
                [owner pushViewController:vc vctitle:@"商家信息" backtitle:kVcDefaultBackTitleName];
                return nil;
            }
        }
    }] catch:^id(id error) {
        [owner hideBlockView];
        [self showOtcError:error];
        return nil;
    }];
}

/*
 *  (public) API - 商家申请进度查询
 *  认证：SIGN 方式 TODO:3.0 修改吗？
 */
- (WsPromise*)merchantProgress:(NSString*)bts_account_name
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/merchant/progress"];
    id args = @{
        @"btsAccount":bts_account_name,
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_sign];
}

/*
 *  (public) API - 商家详情查询
 *  认证：SIGN 方式 TODO:3.0 修改吗？
 */
- (WsPromise*)merchantDetail:(NSString*)bts_account_name
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/merchant/detail"];
    id args = @{
        @"btsAccount":bts_account_name,
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_none];
}

/*
 *  (public) API - 查询商家订单列表
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryMerchantOrders:(NSString*)bts_account_name
                             type:(EOtcOrderType)type
                           status:(EOtcOrderStatus)status
                             page:(NSInteger)page
                        page_size:(NSInteger)page_size
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/merchants/order/list"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"orderType":@(type),
        @"status":@(status),
        @"page":@(page),
        @"pageSize":@(page_size)
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_token];
}

/*
 *  (public) API - 查询订单详情
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryMerchantOrderDetails:(NSString*)bts_account_name order_id:(NSString*)order_id
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/merchants/order/details"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"orderId":order_id,
    };
    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_token];
}

@end
