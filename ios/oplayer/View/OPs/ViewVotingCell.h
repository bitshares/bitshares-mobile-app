//
//  ViewVotingCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>

@interface ViewVotingCell : UIView

- (id)initWithOptions:(id)old_options_json new:(id)new_options_json;

+ (CGFloat)calcViewHeight:(id)old_options_json new:(id)new_options_json;

- (CGFloat)getViewHeight;

@property (nonatomic, assign) NSInteger xOffset;

@end
