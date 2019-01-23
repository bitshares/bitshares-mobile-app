//
//  VCRegisterWalletMode.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCRegisterWalletMode : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithOwner:(VCBase*)owner;

/**
 *  (public) 辅助 - 显示水龙头的时的错误信息，根据 code 进行错误显示便于处理语言国际化。
 */
+ (void)showFaucetRegisterError:(id)response;

@end
