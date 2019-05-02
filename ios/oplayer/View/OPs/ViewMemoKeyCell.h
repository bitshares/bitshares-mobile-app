//
//  ViewMemoKeyCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>

@interface ViewMemoKeyCell : UIView

- (id)initWithOldMemo:(id)old_memokey new:(id)new_memokey title:(NSString*)title;

+ (CGFloat)calcViewHeight:(id)old_permission_json new:(id)new_permission_json;

- (CGFloat)getViewHeight;

@property (nonatomic, assign) NSInteger xOffset;

@end
