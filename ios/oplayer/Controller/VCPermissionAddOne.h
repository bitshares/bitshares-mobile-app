//
//  VCPermissionAddOne.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  新增权限界面

#import "VCBase.h"

@interface VCPermissionAddOne : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithResultPromise:(WsPromiseObject*)result_promise;

@end
