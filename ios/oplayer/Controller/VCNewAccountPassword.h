//
//  VCNewAccountPassword.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCNewAccountPassword : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithNewAccountName:(NSString*)new_account_name;

@end
