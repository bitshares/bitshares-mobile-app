//
//  VCLoginPasswordMode.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

typedef void (^LoginSuccessCallback)();

@interface VCLoginPasswordMode : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithOwner:(VCBase*)owner checkActivePermission:(BOOL)checkActivePermission;

@property (nonatomic, copy)NSString* tmpUsername;
@property (nonatomic, copy)NSString* tmpPassword;

@end
