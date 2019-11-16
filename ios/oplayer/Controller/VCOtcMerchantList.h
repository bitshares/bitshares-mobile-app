//
//  VCOtcMerchantList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  场外交易-在线商家列表

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"
#import "OtcManager.h"

@interface VCOtcMerchantList : VCBase<UITableViewDelegate, UITableViewDataSource>

- (id)initWithOwner:(VCBase*)owner ad_type:(EOtcAdType)ad_type;
- (void)queryAdList:(NSString*)asset_id;

@end

@interface VCOtcMerchantListPages : VCSlideControllerBase

- (id)initWithAssetName:(NSString*)asset_name ad_type:(EOtcAdType)ad_type;

@end
