//
//  MBProgressHUDSingleton.h
//  oplayer
//
//  Created by Aonichan on 15-11-26.
//
//

#import <Foundation/Foundation.h>

@interface MBProgressHUDSingleton : NSObject

+(MBProgressHUDSingleton*)sharedMBProgressHUDSingleton;

- (BOOL)is_showing;
- (void)showWithTitle:(NSString*)pTitle andView:(UIView*)pOwnerView;
- (void)showWithTitle:(NSString *)pTitle subTitle:(NSString*)pSubTitle andView:(UIView *)pOwnerView;
- (void)hide;
- (void)removeCancelButton;
- (void)addCancelButtonWithTarget:(id)target action:(SEL)action;
- (void)updateTitle:(NSString*)pTitle subTitle:(NSString*)pSubTitle;

@end