//
//  VCTransferToBlind.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  转入隐私账户

#import "VCBase.h"

@interface VCTransferToBlind : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data;

@end
