//
//  VCTransfer.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCTransfer : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithUserFullInfo:(NSDictionary*)full_account_data defaultAsset:(NSDictionary*)defaultAsset;

@end
