//
//  ViewProposalOpInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewProposalOpInfoCell : UITableViewCellBase

@property (nonatomic, strong) NSDictionary* item;
@property (nonatomic, assign) BOOL useLabelFont;
@property (nonatomic, assign) BOOL useBuyColorForTitle;

+ (CGFloat)getCellHeight:(NSDictionary*)item leftOffset:(CGFloat)leftOffset;

@end
