//
//  VCUserAssets.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

@interface VCAccountInfoPages : VCSlideControllerBase

- (id)initWithUserAssetDetailInfos:(NSDictionary*)userAssetDetailInfos assetHash:(NSDictionary*)assetHash accountInfo:(NSDictionary*)accountInfo;

@end

@interface VCUserAssets : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner
   assetDetailInfos:(NSDictionary*)userAssetDetailInfos
          assetHash:(NSDictionary*)assetHash
        accountInfo:(NSDictionary*)accountInfo;

@end
