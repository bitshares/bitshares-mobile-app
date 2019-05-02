//
//  ViewProposalOpInfoCell_AccountUpdate.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//  部分OP特化显示。

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewProposalOpInfoCell_AccountUpdate : UITableViewCellBase

@property (nonatomic, strong) NSDictionary* item;
@property (nonatomic, assign) BOOL useLabelFont;
@property (nonatomic, assign) BOOL useBuyColorForTitle;

+ (CGFloat)getCellHeight:(NSDictionary*)item leftOffset:(CGFloat)leftOffset;

@end
