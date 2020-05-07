//
//  VCNewAccountPassword.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

enum
{
    kNewPasswordSceneRegAccount = 0,            //  注册新账号（额外参数：账号名）
    kNewPasswordSceneChangePassowrd,            //  修改密码
    kNewPasswordSceneGenBlindAccountBrainKey    //  生成隐私账号助记词
};

@interface VCNewAccountPassword : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithScene:(NSInteger)scene args:(NSString*)new_account_name;

@end
