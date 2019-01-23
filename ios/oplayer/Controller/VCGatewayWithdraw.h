//
//  VCGatewayWithdraw.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  网关提币

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCGatewayWithdraw : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithFullAccountData:(NSDictionary*)fullAccountData
          intermediateAccount:(NSDictionary*)intermediateAccount
            withdrawAssetItem:(NSDictionary*)withdrawAssetItem
                      gateway:(id)gateway;

@end
