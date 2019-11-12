//
//  OtcManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "OtcManager.h"
#import "OrgUtils.h"

static OtcManager *_sharedOtcManager = nil;

@interface OtcManager()
{
    NSString*   _base_api;
}
@end

@implementation OtcManager

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
    }
    return self;
}

- (void)dealloc
{
}

/*
 *  (public) 查询OTC用户身份认证信息。
 *  bts_account_name    - BTS账号名
 */
- (WsPromise*)queryIdVerify:(NSString*)bts_account_name
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/otc/queryIdVerify"];
    //  TODO:2.9服务器暂时没验证签名？
    id headers = @{
        @"btsAccount":bts_account_name,
        @"dataVerify":@"",//TODO:2.9
        @"dataVerifyType":@"",//TODO:2.9
        @"holderVerify":@"",//TODO:2.9
    };
    return [OrgUtils asyncPostUrl_jsonBody:url args:@{} headers:headers];
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
    return [OrgUtils asyncPostUrl_jsonBody:url args:@{@"type":@(asset_type)}];
}

/*
 *  (public) 查询OTC商家广告列表。
 *  ad_status   - 广告状态 默认值：eoads_online
 *  ad_type     - 状态类型
 *  page        - 页号
 *  page_size   - 每页数量
 */
- (WsPromise*)queryAdList:(EOtcAdType)ad_type page:(NSInteger)page page_size:(NSInteger)page_size
{
    return [self queryAdList:eoads_online type:ad_type page:page page_size:page_size];
}

- (WsPromise*)queryAdList:(EOtcAdStatus)ad_status type:(EOtcAdType)ad_type page:(NSInteger)page page_size:(NSInteger)page_size
{
    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/ad/list"];
    id args = @{
        @"adStatus":@(ad_status),
        @"adType":@(ad_type),
        @"page":@(page),
        @"pageSize":@(page_size)
    };
    return [OrgUtils asyncPostUrl_jsonBody:url args:args];
}

@end
