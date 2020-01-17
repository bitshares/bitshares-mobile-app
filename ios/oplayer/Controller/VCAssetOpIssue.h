//
//  VCAssetOpIssue.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCAssetOpIssue : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAsset:(NSDictionary*)asset dynamic_asset_data:(id)dynamic_asset_data;

@end
