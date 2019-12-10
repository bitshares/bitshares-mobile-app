//
//  VCOtcMcPaymentMethods.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC商家付款方式列表

#import "VCBase.h"

@interface VCOtcMcPaymentMethods : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info;

@end
