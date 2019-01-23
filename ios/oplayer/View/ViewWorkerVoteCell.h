//
//  ViewWorkerVoteCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewWorkerVoteCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc;

@property (nonatomic, assign) double bts_precision_pow;
@property (nonatomic, strong) NSDictionary* item;

- (void)setTagData:(NSInteger)tag;
- (void)setVotingInfo:(NSDictionary*)voting_info;

@end
