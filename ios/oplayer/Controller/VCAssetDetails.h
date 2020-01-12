//
//  VCAssetDetails.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  石墨烯资产详细信息

#import "VCBase.h"

@interface VCAssetDetails : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAssetID:(NSString*)asset_id asset:(id)asset bitasset_data:(id)bitasset_data dynamic_asset_data:(id)dynamic_asset_data;

@end
