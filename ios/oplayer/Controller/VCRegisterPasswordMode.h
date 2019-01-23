//
//  VCRegisterPasswordMode.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCRegisterPasswordMode : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithOwner:(VCBase*)owner;

@end
