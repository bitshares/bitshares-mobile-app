//
//  MainNavController.h
//  oplayer
//
//  Created by SYALON on 13-8-1.
//
//

#import <UIKit/UIKit.h>

@interface MyNavigationController : UINavigationController

- (BOOL)shouldAutorotate;
- (NSUInteger)supportedInterfaceOrientations;
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation;

- (void)tempEnableDragBack;
- (void)tempDisableDragBack;

- (void)switchTheme;
- (void)switchLanguage;

@end
