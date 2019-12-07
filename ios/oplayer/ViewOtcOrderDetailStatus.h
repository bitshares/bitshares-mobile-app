//
//  ViewOtcOrderDetailStatus.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@class VCBase;

@interface ViewOtcOrderDetailStatus : UITableViewCellBase

@property (nonatomic, strong) NSDictionary* item;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(VCBase*)vc;

- (void)refreshText;

@end
