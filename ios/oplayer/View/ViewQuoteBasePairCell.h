//
//  ViewQuoteBasePairCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "OtcManager.h"

@interface ViewQuoteBasePairCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc;

@property (nonatomic, strong) NSDictionary* item;

@end
