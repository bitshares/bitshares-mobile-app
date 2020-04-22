//
//  ViewEmptyInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-19.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewEmptyInfoCell : UITableViewCellBase

- (id)initWithText:(NSString*)pText iconName:(NSString*)iconName;

@property (nonatomic, strong) UIImageView* imgIcon;
@property (nonatomic, strong) UILabel* lbText;

@end
