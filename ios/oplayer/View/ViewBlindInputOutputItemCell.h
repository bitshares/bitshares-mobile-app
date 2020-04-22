//
//  ViewBlindInputOutputItemCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

enum
{
    kBlindItemTypeInput = 0,
    kBlindItemTypeOutput
};

@interface ViewBlindInputOutputItemCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier vc:(UIViewController*)vc action:(SEL)action;

@property (nonatomic, strong) NSDictionary* item;
@property (nonatomic, assign) NSInteger itemType;

- (void)setTagData:(NSInteger)tag;

@end
