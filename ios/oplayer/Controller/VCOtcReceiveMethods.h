//
//  VCOtcReceiveMethods.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  收款方式列表

#import "VCBase.h"
#import "OtcManager.h"

@interface VCOtcReceiveMethods : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type;

@end
