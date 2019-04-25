//
//  ViewActionsCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@class ViewActionsCell;

@protocol ViewActionsCellClickedDelegate <NSObject>
@required
- (void)onButtonClicked:(ViewActionsCell*)cell infos:(id)infos;
@end

@interface ViewActionsCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier buttons:(NSArray*)buttons;

@property (nonatomic, strong) NSDictionary* item;
@property (nonatomic, assign) id<ViewActionsCellClickedDelegate> button_delegate;
@property (nonatomic, assign) NSInteger user_tag;

@end
