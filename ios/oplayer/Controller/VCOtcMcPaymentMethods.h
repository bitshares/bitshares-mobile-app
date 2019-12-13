//
//  VCOtcMcPaymentMethods.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC商家付款方式界面

#import "VCBase.h"
#import "OtcManager.h"

@interface VCOtcMcPaymentMethods : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info merchant_detail:(id)merchant_detail;

@end
