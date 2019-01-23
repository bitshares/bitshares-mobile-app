//
//  ViewKLineButtons.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@class VCBase;
@interface ViewKLineButtons : UITableViewCellBase

- (id)initWithFrame:(CGRect)frame button_infos:(NSDictionary*)button_infos owner:(VCBase*)owner action:(SEL)action;

@end
