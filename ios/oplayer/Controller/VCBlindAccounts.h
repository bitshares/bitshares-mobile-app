//
//  VCBlindAccounts.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  隐私地址管理

#import "VCBase.h"

@interface VCBlindAccounts : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithResultPromise:(WsPromiseObject*)result_promise;

@end
