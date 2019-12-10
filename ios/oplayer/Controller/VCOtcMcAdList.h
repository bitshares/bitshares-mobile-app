//
//  VCOtcMcAdList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC商家广告管理

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCOtcMcAdList : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithAuthInfo:(id)auth_info;

@end
