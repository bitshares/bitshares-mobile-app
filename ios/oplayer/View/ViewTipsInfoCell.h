//
//  ViewTipsInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewTipsInfoCell : UITableViewCellBase

- (id)initWithText:(NSString*)pText;
- (void)updateLabelText:(NSString*)text;
- (CGFloat)calcCellDynamicHeight:(CGFloat)leftOffset;

@end
