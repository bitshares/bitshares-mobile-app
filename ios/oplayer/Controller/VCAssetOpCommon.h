//
//  VCAssetOpCommon.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  资产部分通用操作界面 资产销毁/资产清算

#import "VCBase.h"
#import "ViewTextFieldAmountCell.h"

@interface VCAssetOpCommon : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, ViewTextFieldAmountCellDelegate>

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
          op_extra_args:(id)op_extra_args
         result_promise:(WsPromiseObject*)result_promise;

@end
