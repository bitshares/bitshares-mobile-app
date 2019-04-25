//
//  ViewCallOrderInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewCallOrderInfoCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;

@property (nonatomic, copy) NSDecimalNumber* feedPriceInfo;
@property (nonatomic, copy) NSDecimalNumber* mcr;

@property (nonatomic, strong) NSDictionary* item;

@property (nonatomic, assign) NSInteger debt_precision;
@property (nonatomic, assign) NSInteger collateral_precision;

@end
