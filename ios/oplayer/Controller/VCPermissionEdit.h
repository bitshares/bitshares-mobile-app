//
//  VCPermissionEdit.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  用户权限编辑界面

#import "VCBase.h"

@interface VCPermissionEdit : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithPermissionJson:(id)permission maximum_authority_membership:(NSInteger)maximum_authority_membership
              result_promise:(WsPromiseObject*)result_promise;

@end
