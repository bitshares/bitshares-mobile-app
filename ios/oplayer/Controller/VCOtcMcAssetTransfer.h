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
            asset_list:(id)asset_list
   curr_merchant_asset:(id)curr_merchant_asset
     full_account_data:(id)full_account_data
           transfer_in:(BOOL)transfer_in
        result_promise:(WsPromiseObject*)result_promise;

@end
