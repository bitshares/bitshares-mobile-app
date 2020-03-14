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

@property (nonatomic, strong, readonly) NSMutableArray* words;

- (NSString*)current_password;
- (void)updateWithNewContent:(NSArray*)new_words lang:(EBitsharesAccountPasswordLang)lang;

@end
