//
//  ViewOtcPaymentIconAndTextCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//  场外交易订单详情界面 付款方式 图标加简短账号信息视图。

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "OtcManager.h"

@interface ViewOtcPaymentIconAndTextCell : UITableViewCellBase

@property (nonatomic, assign) EOtcUserType userType;
@property (nonatomic, assign) BOOL bUserSell;
@property (nonatomic, strong) NSDictionary* item;

@end
