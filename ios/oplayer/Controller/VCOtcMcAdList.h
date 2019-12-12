//
//  VCOtcMcAdList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  商家广告管理

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"
#import "OtcManager.h"

@interface VCOtcMcAdListPages : VCSlideControllerBase

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail;

@end

@interface VCOtcMcAdList : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner authInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail
          ad_status:(EOtcAdStatus)ad_status;

- (void)queryMerchantAdList;

@end
