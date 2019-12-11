//
//  ViewOtcMcMerchantBasicCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "OtcManager.h"

@interface ViewOtcMcMerchantBasicCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;

@property (nonatomic, strong) NSDictionary* item;

@end
