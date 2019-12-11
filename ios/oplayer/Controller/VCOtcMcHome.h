//
//  VCOtcMcHome.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  OTC商家主界面

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCOtcMcHome : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithProgressInfo:(id)progress_info merchantDetail:(id)merchant_detail;

@end
