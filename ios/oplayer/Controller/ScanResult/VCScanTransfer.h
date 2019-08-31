//
//  VCScanTransfer.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCScanTransfer : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithTo:(NSDictionary*)to_account asset:(NSDictionary*)asset amount:(NSString*)amount memo:(NSString*)memo;

@end
