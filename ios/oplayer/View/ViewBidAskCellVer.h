//
//  ViewBidAskCellVer.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//  竖版交易界面

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewBidAskCellVer : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier isbuy:(BOOL)isbuy;

- (void)setRowID:(NSInteger)_id maxSum:(double)maxSum;

@property (nonatomic, strong) NSDictionary* userLimitOrderHash;
@property (nonatomic, assign) NSInteger displayPrecision;
@property (nonatomic, assign) NSInteger numPrecision;
@property (nonatomic, strong) NSDictionary* item;

@end
