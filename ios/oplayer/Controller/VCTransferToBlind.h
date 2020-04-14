//
//  VCTransferToBlind.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  隐私转账

#import "VCBase.h"

@interface VCTransferToBlind : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
          op_extra_args:(id)op_extra_args
         result_promise:(WsPromiseObject*)result_promise;

@end
