//
//  VCAssetCreateOrEdit.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  创建或编辑资产

#import "VCBase.h"

@interface VCAssetCreateOrEdit : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithEditAssetOptions:(NSDictionary*)asset_options editBitassetOpts:(NSDictionary*)bitasset_opts;

@end
