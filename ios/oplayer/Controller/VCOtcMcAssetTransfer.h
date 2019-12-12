//
//  VCOtcMcAssetTransfer.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  商家资产划转（个人账户和OTC账户之间转移）

#import "VCBase.h"
#import "OtcManager.h"

@interface VCOtcMcAssetTransfer : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info
             user_type:(EOtcUserType)user_type
       merchant_detail:(id)merchant_detail
          balance_info:(id)balance_info
           transfer_in:(BOOL)transfer_in;

@end
