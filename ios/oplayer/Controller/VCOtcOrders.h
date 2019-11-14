//
//  VCOtcOrders.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC订单管理

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

@interface VCOtcOrdersPages : VCSlideControllerBase


@end

@interface VCOtcOrders : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner current:(BOOL)current;

@end
