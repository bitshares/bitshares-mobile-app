//
//  ViewOtcMerchantInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewOtcMerchantInfoCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;

@property (nonatomic, assign) BOOL isBuy;
@property (nonatomic, strong) NSDictionary* item;

@end
