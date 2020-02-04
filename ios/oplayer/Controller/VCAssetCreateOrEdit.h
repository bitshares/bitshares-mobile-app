//
//  VCAssetCreateOrEdit.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  创建或编辑资产

#import "VCBase.h"

@interface VCAssetCreateOrEdit : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithEditAsset:(NSDictionary*)asset editBitassetOpts:(NSDictionary*)bitasset_opts result_promise:(WsPromiseObject*)result_promise;

@end
