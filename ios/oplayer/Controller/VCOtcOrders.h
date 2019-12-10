//
//  VCOtcOrders.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC订单管理

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCOtcOrders : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info;

@end
