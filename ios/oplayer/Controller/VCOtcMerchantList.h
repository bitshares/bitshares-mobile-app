//
//  VCOtcMerchantList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  场外交易-在线商家列表

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

@interface VCOtcMerchantList : VCBase<UITableViewDelegate, UITableViewDataSource>

- (id)initWithOwner:(VCBase*)owner userbuy:(BOOL)userbuy;
- (void)onMerchantListResponsed:(id)data;

@end

@interface VCOtcMerchantListPages : VCSlideControllerBase

@end
