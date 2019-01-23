//
//  VCConvertToWalletMode.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  密码模式转换为钱包模式。

#import <UIKit/UIKit.h>
#import "VCBase.h"

typedef void (^BtsppCloseCallback)();

@interface VCConvertToWalletMode : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithCallback:(BtsppCloseCallback)callback;

@end
