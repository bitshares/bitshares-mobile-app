//
//  VCAssetOpGlobalSettle.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  资产全局清算

#import "VCBase.h"

@interface VCAssetOpGlobalSettle : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithCurrAsset:(id)curr_asset bitasset_data:(id)bitasset_data
         result_promise:(WsPromiseObject*)result_promise;

@end
