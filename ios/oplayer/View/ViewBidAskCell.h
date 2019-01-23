//
//  ViewBidAskCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewBidAskCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier isbuy:(BOOL)isbuy;

- (void)setRowID:(NSInteger)_id maxSum:(double)maxSum;

@property (nonatomic, assign) NSInteger displayPrecision;
@property (nonatomic, assign) NSInteger numPrecision;
@property (nonatomic, strong) NSDictionary* item;

@end
