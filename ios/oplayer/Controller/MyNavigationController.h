//
//  MainNavController.h
//  oplayer
//
//  Created by SYALON on 13-8-1.
//
//

#import <UIKit/UIKit.h>

@interface MyNavigationController : UINavigationController<UIGestureRecognizerDelegate>

@property (nonatomic, assign) BOOL disablePopGesture;

- (BOOL)shouldAutorotate;
- (NSUInteger)supportedInterfaceOrientations;
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation;

/*
 *  (public) 启用/禁用 拖拽返回上一个界面。
 */
- (void)tempEnableDragBack;
- (void)tempDisableDragBack;

- (void)switchTheme;
- (void)switchLanguage;

@end
