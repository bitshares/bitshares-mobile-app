//
//  ViewTradeHistoryCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewTradeHistoryCell : UITableViewCellBase

@property (nonatomic, assign) NSInteger displayPrecision;
@property (nonatomic, assign) NSInteger numPrecision;
@property (nonatomic, strong) NSDictionary* item;

@end
