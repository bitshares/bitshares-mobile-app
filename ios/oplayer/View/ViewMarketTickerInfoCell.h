//
//  ViewMarketTickerInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewMarketTickerInfoCell : UITableViewCellBase

- (void)setGroupInfo:(NSDictionary*)group_info;

@property (nonatomic, strong) NSDictionary* item;

@end
