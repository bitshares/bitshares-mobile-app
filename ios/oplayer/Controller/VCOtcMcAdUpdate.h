//
//  VCOtcMcAdUpdate.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  商家广告创建or编辑界面

#import "VCBase.h"
#import "OtcManager.h"

@interface VCOtcMcAdUpdate : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail ad_info:(id)curr_ad_info
        result_promise:(WsPromiseObject*)result_promise;

@end
