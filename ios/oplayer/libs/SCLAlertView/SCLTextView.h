//
//  SCLTextView.h
//  SCLAlertView
//
//  Created by Diogo Autilio on 9/18/15.
//  Copyright © 2015-2016 AnyKey Entertainment. All rights reserved.
//

#if defined(__has_feature) && __has_feature(modules)
@import UIKit;
#else
#import <UIKit/UIKit.h>
#endif

#import "MyTextField.h"

@interface SCLTextView : MyTextField

@property (nonatomic, assign) NSInteger iDecimalPrecision;  //  小数精度：0 - 整数键盘 >0 - 小数键盘(该参数指定小数位数) <0 - 普通键盘

- (BOOL)isValidAuthorityThreshold:(NSString*)new_string;

@end
