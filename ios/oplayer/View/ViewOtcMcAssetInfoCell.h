//
//  ViewOtcMcAssetInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewOtcMcAssetInfoCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc;
- (void)setTagData:(NSInteger)tag;

@property (nonatomic, strong) NSDictionary* item;

@end
