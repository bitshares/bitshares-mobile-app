//
//  VCPermissionList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  用户权限列表，包含所有者权限、资金权限、备注权限以及可能存在的自定义权限。（BSIP40：https://github.com/bitshares/bsips/blob/master/bsip-0040.md）

#import "VCBase.h"

@interface VCPermissionList : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner;
- (void)refreshCurrAccountData;

@end
