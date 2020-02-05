//
//  VCAssetOpIssue.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"
#import "ViewTextFieldAmountCell.h"

@interface VCAssetOpIssue : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, ViewTextFieldAmountCellDelegate>

- (id)initWithAsset:(NSDictionary*)asset dynamic_asset_data:(id)dynamic_asset_data result_promise:(WsPromiseObject*)result_promise;

@end
