//
//  VCOtcOrders.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC订单管理

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"
#import "OtcManager.h"

@interface VCOtcOrdersPages : VCSlideControllerBase

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type;

@end

@interface VCOtcOrders : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner authInfo:(id)auth_info user_type:(EOtcUserType)user_type order_status:(EOtcOrderStatus)order_status;

- (void)queryCurrentPageOrders;

@end
