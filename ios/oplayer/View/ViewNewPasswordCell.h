//
//  ViewNewPasswordCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "bts_chain_config.h"

@interface ViewNewPasswordCell : UITableViewCellBase

- (void)updateWithNewContent:(NSString*)new_password lang:(EBitsharesAccountPasswordLang)lang;

@end
