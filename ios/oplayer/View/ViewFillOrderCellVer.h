//
//  ViewFillOrderCellVer.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//  成交历史（竖版交易界面）

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewFillOrderCellVer : UITableViewCellBase

@property (nonatomic, assign) NSInteger displayPrecision;
@property (nonatomic, assign) NSInteger numPrecision;
@property (nonatomic, strong) NSDictionary* item;

@end
