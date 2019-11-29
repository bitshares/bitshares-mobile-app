//
//  VCOtcOrderDetails.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC订单详情界面

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCOtcOrderDetails : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOrder:(id)order details:(id)order_details auth:(id)auth_info;

@end
