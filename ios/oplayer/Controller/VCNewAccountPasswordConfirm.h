//
//  VCNewAccountPasswordConfirm.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCNewAccountPasswordConfirm : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithPassword:(NSString*)password passlang:(EBitsharesAccountPasswordLang)passlang;

@end
