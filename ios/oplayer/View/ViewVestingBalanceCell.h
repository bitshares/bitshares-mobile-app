//
//  ViewVestingBalanceCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewVestingBalanceCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc;

@property (nonatomic, strong) NSDictionary* item;
@property (nonatomic, assign) NSInteger row;

- (void)setTagData:(NSInteger)tag;

@end
