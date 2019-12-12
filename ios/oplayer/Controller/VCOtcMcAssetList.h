//
//  VCOtcMcAssetList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  商家资产管理

#import "VCBase.h"
#import "OtcManager.h"

@interface VCOtcMcAssetList : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail;

@end
