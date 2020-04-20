//
//  VCBlindTransfer.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  隐私账户间转账

#import "VCBase.h"

@interface VCBlindTransfer : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
         result_promise:(WsPromiseObject*)result_promise;

@end
