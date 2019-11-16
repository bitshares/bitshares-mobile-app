//
//  ViewOtcMerchantInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "OtcManager.h"

@interface ViewOtcMerchantInfoCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(VCBase*)vc;
- (void)setTagData:(NSInteger)tag;

@property (nonatomic, assign) EOtcAdType adType;
@property (nonatomic, strong) NSDictionary* item;

@end
