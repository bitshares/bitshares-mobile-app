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
        //    alias = "\U4eba\U6c11\U5e01";
        //    assetId = "1.0.1";
        //    assetPrecision = 2;
        //    btsId = "<null>";
        //    symbol = CNY;
        //    type = 1;
        //}
        id symbol = _fiat_cny_info[@"symbol"];
        id precision = _fiat_cny_info[@"assetPrecision"];
        id assetId = _fiat_cny_info[@"assetId"];
        //  TODO:2.9 short_symbol
        return @{@"symbol":symbol, @"precision":precision, @"id":assetId, @"short_symbol":@"¥", @"name":_fiat_cny_info[@"alias"]};
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
            if ([[item objectForKey:@"symbol"] isEqualToString:asset_name]) {
                return YES;
            }
        }
    }
    return NO;
}

/*
 *  (public) 转到OTC界面，会自动初始化必要信息。
 */
- (void)gotoOtc:(VCBase*)owner asset_name:(NSString*)asset_name ad_type:(EOtcAdType)ad_type
{
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
                if ([[fiat_info objectForKey:@"symbol"] isEqualToString:@"CNY"]) {
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
        @"ordertype":@(type),
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
        @"assetName":asset_name,
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
 */
- (WsPromise*)_queryApiCore:(NSString*)url args:(id)args headers:(id)headers
{
    //  TODO:2.9 签名认证
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [[[OrgUtils asyncPostUrl_jsonBody:url args:args headers:headers] then:^id(id responsed) {
            //  TODO:2.9 lang
            if (!responsed || ![responsed isKindOfClass:[NSDictionary class]]) {
                reject(@"服务器或网络异常，请稍后再试。");
                return nil;
            }
            NSInteger code = [[responsed objectForKey:@"code"] integerValue];
            if (code != 0) {
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
