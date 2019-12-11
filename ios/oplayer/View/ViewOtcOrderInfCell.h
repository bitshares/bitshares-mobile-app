//
//  ViewOtcOrderInfCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "OtcManager.h"

@interface ViewOtcOrderInfCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc;

@property (nonatomic, assign) EOtcUserType userType;
@property (nonatomic, strong) NSDictionary* item;

@end
