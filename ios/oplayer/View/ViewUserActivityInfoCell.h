//
//  ViewUserActivityInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewUserActivityInfoCell : UITableViewCellBase

@property (nonatomic, strong) NSDictionary* item;

+ (CGFloat)getCellHeight:(NSDictionary*)item leftMargin:(CGFloat)leftMargin;

@end
