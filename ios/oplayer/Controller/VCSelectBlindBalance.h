//
//  VCSelectBlindBalance.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  选择要参与隐私转账的输入收据信息

#import "VCBase.h"

@interface VCSelectBlindBalance : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithResultPromise:(WsPromiseObject*)result_promise default_selected:(NSDictionary*)default_selected;

@end
