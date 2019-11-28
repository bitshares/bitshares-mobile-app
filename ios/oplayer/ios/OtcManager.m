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
 *  (public) 辅助 - 根据订单当前状态获取主状态、状态描述、以及可操作按钮等信息。
 */
+ (NSDictionary*)genUserOrderStatusAndActions:(id)order
{
    assert(order);
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    BOOL bUserSell = [[order objectForKey:@"type"] integerValue] == eoot_data_sell;
    NSInteger status = [[order objectForKey:@"status"] integerValue];
    NSString* status_main = nil;
    NSString* status_desc = nil;
    NSMutableArray* actions = [NSMutableArray array];
    BOOL showRemark = NO;
    //  TODO:2.9 状态描述待细化。!!!!
    
    if (bUserSell) {
        //  -- 用户卖币提现
        switch (status) {
            //  正常流程
            case eoops_new:
            {
                status_main = @"待转币";               //  已下单(待转币)     正常情况下单自动转币、转币操作需二次确认
                status_desc = @"您已成功下单，请转币。";
                [actions addObject:@{@"type":@(eooot_contact_customer_service), @"color":theme.textColorGray}];
                [actions addObject:@{@"type":@(eooot_transfer), @"color":theme.textColorHighlight}];
            }
                break;
            case eoops_already_transferred:
            {
                status_main = @"确认中";               //  已转币(待处理)
                status_desc = @"您已转币，正在等待区块确认。";
            }
                break;
            case eoops_already_confirmed:
                status_main = @"区块已确认(待收款)";
                break;
            case eoops_already_paid:
                status_main = @"已付款(请放行)";  // 申诉 + 确认收款(放行操作需二次确认)
                break;
            case eoops_completed:
            {
                status_main = @"已完成";
                status_desc = @"订单已完成。";
            }
                break;
            //  异常流程
            case eoops_chain_failed:
                status_main = @"区块异常";       // 申诉
                break;
            case eoops_return_assets:
                status_main = @"退币中";
                break;
            case eoops_cancelled:
            {
                status_main = @"已取消";
                status_desc = @"订单已取消。";
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
                status_main = @"已下单(待付款)";  // 取消 + 确认付款
                showRemark = YES;
                break;
            case eoops_already_paid:
                status_main = @"已付款(待收币)";
                break;
            case eoops_already_transferred:
                status_main = @"已转币";
                break;
            case eoops_already_confirmed:
                status_main = @"区块已确认";
                break;
            case eoops_completed:
            {
                status_main = @"已完成";
                status_desc = @"订单已完成。";
            }
                break;
            //  异常流程
            case eoops_refunded:
                status_main = @"已退款";
                break;
            case eoops_chain_failed:
                status_main = @"区块异常";
                break;
            case eoops_cancelled:
            {
                status_main = @"已取消";
                status_desc = @"订单已取消。";
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
             @"phone":order[@"phone"] ?: @"", @"show_remark":@(showRemark)};
}

/*
 *  (public) 当前账号名
 */
- (NSString*)getCurrentBtsAccount
{
    assert([[WalletManager sharedWalletManager] isWalletExist]);
    return @"say007";//TODO:2.9 test data
//    return [[WalletManager sharedWalletManager] getWalletAccountName];
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
    assert(asset_name);
    [owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    WsPromise* p1 =  [self queryAssetList:eoat_fiat];
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

/*
 *  (public) 显示OTC的错误信息。
 */
- (void)showOtcError:(id)error
{
    //  TODO:2.9 咨询 error code表。验证码错误 等 需要显示对应文案。
    
    //  显示错误信息
    NSString* errmsg = nil;
    if (error && [error isKindOfClass:[WsPromiseException class]]){
        WsPromiseException* excp = (WsPromiseException*)error;
        errmsg = excp.reason;
    }
    if (!errmsg || [errmsg isEqualToString:@""]) {
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
 *  (public) 查询OTC用户身份认证信息。
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
    return [self _queryApiCore:url args:@{@"btsAccount":bts_account_name} headers:nil];
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
    return [self _queryApiCore:url args:args headers:nil];
}

/*
 *  (public) 查询用户订单列表
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
    return [self _queryApiCore:url args:args headers:nil];
}

/*
 *  (public) 查询订单详情
 */
- (WsPromise*)queryUserOrderDetails:(NSString*)bts_account_name order_id:(NSString*)order_id
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/user/order/details"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"orderId":order_id,
    };
    return [self _queryApiCore:url args:args headers:nil];
}

/*
 *  (public) 查询用户收款方式
 */
- (WsPromise*)queryPaymentMethods:(NSString*)bts_account_name
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/payMethod/query"];
    id args = @{
        @"btsAccount":bts_account_name,
    };
    return [self _queryApiCore:url args:args headers:nil];
}

- (WsPromise*)addPaymentMethods:(id)args
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/payMethod/add"];
    return [self _queryApiCore:url args:args headers:nil];
}

- (WsPromise*)delPaymentMethods:(NSString*)bts_account_name
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/payMethod/del"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"id":@0,   //  TODO:2.9 未完成
        @"status":@0    //  TODO:2.9 未完成
    };
    return [self _queryApiCore:url args:args headers:nil];
}

- (WsPromise*)editPaymentMethods:(NSString*)bts_account_name
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/payMethod/edit"];
    id args = @{
        @"btsAccount":bts_account_name,
        @"id":@0,   //  TODO:2.9 未完成
        @"status":@0    //  TODO:2.9 未完成
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
    return [self _queryApiCore:url args:args headers:nil as_json:NO];
}

/*
 *  (public) 查询OTC支持的数字资产列表（bitCNY、bitUSD、USDT等）
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
 *  (public) 查询OTC商家广告列表。
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

/*
 *  (public) 查询广告详情。
 */
- (WsPromise*)queryAdDetails:(NSString*)ad_id
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/ad/detail"];
    id args = @{
        @"adId":ad_id,
    };
    return [self _queryApiCore:url args:args headers:nil];
}

/*
 *  (public) 锁定价格
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
    return [self _queryApiCore:url args:args headers:nil];
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
 *  (private) 执行OTC网络请求。
 *  as_json     - 是否返回 json 格式，否则返回原始数据流。
 */
- (WsPromise*)_queryApiCore:(NSString*)url args:(id)args headers:(id)headers
{
    return [self _queryApiCore:url args:args headers:headers as_json:YES];
}

- (WsPromise*)_queryApiCore:(NSString*)url args:(id)args headers:(id)headers as_json:(BOOL)as_json
{
    //  TODO:2.9 签名认证
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
            if (code != 0) {
                //  TODO:2.9 部分 error code 特殊多语言 处理 。
                id msg = [responsed objectForKey:@"message"];
                if (msg && ![msg isEqualToString:@""]) {
                    reject([NSString stringWithFormat:@"%@", @{@"code":@(code), @"message":msg}]);
                } else {
                    reject([NSString stringWithFormat:@"服务器或网络异常，请稍后再试。错误代码：%@", @(code)]);
                }
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

@end
