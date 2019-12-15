//
//  VCOtcAddAlipay.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC用户添加收款方式-支付宝

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCOtcAddAlipay : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info result_promise:(WsPromiseObject*)result_promise;

@end
