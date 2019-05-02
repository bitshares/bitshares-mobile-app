//
//  ViewPermissionCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>

@interface ViewPermissionCell : UIView

- (id)initWithPermission:(id)old_permission_json new:(id)new_permission_json title:(NSString*)title;

+ (CGFloat)calcViewHeight:(id)old_permission_json new:(id)new_permission_json;

- (CGFloat)getViewHeight;

@property (nonatomic, assign) NSInteger xOffset;

@end
