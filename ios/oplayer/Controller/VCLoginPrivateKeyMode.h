//
//  VCLoginPrivateKeyMode.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

typedef void (^LoginSuccessCallback)();

@interface VCLoginPrivateKeyMode : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithOwner:(VCBase*)owner checkActivePermission:(BOOL)checkActivePermission;

@property (nonatomic, copy)NSString* tmpPassword;

@end
