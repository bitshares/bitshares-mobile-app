//
//  MyTabBarController.h
//  oplayer
//
//  Created by SYALON on 13-9-30.
//
//

#import <Foundation/Foundation.h>

@interface MyTabBarController : UITabBarController<UITabBarControllerDelegate>

- (id)init;
- (BOOL)shouldAutorotate;
- (NSUInteger)supportedInterfaceOrientations;
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation;

@end
