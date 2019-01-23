//
//  VCUserActivity.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  用户活跃情况（帐号明细）

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCUserActivity : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAccountInfo:(NSDictionary*)accountInfo;

@end
