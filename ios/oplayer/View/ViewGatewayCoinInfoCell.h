//
//  ViewGatewayCoinInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@class VCBase;

@interface ViewGatewayCoinInfoCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(VCBase*)vc;
- (void)setTagData:(NSInteger)tag;

@property (nonatomic, strong) NSDictionary* item;

@end
