//
//  VCOtcMcAssetList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC商家资产

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCOtcMcAssetList : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info;

@end
