//
//  MyTabBarController.m
//  oplayer
//
//  Created by SYALON on 13-9-30.
//
//

#import "MyTabBarController.h"
#import "MyNavigationController.h"
#import "VCDebt.h"

@interface MyTabBarController ()
{
    NSInteger   vcDebtIndex;        //  抵押借贷界面所在 tabcontroller 中的索引位置。
}

@end

@implementation MyTabBarController

- (void)dealloc
{
}

- (id)init
{
    self = [super init];
    if (self)
    {
        vcDebtIndex = -1;
        self.delegate = self;
    }
    return self;
}

- (BOOL)shouldAutorotate
{
    return self.selectedViewController.shouldAutorotate;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return self.selectedViewController.supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return self.selectedViewController.preferredInterfaceOrientationForPresentation;
}

#pragma mark- for UITabBarControllerDelegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController NS_AVAILABLE_IOS(3_0)
{
    if (vcDebtIndex < 0){
        NSUInteger idx = 0;
        for (MyNavigationController* navi in tabBarController.viewControllers) {
            UIViewController* root = [navi.viewControllers firstObject];
            if (root && [root isKindOfClass:[VCDebt class]]){
                vcDebtIndex = idx;
                break;
            }
            idx += 1;
        }
    }
    if (vcDebtIndex >= 0 && tabBarController.selectedIndex != vcDebtIndex){
        UINavigationController* nav = (UINavigationController*)viewController;
        UIViewController* root = [nav.viewControllers firstObject];
        if (root && [root isKindOfClass:[VCDebt class]]){
            //  准备切换到 VCDebt 界面
            [(VCDebt*)root onTabBarControllerSwitched];
        }
    }
    return YES;
}

@end
