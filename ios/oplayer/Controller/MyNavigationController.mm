//
//  MainNavController.m
//  oplayer
//
//  Created by SYALON on 13-8-1.
//
//

#import "MyNavigationController.h"
#import "NativeAppDelegate.h"

@interface MyNavigationController()
{
    BOOL _tempEnableDragBack;       //  临时禁用拖拽返回（比如在显示阻塞界面等情况下）
}

@end

@implementation MyNavigationController

- (void)dealloc
{
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    _tempEnableDragBack = NO;
}

/**
 *  获取截屏
 */
- (UIImage*)capture
{
    UIView* pView = nil;
    if (self.tabBarController)
    {
        pView = self.tabBarController.view;
    }
    else if (self.navigationController)
    {
        pView = self.navigationController.view;
    }
    else
    {
        pView = self.view;
    }
    UIGraphicsBeginImageContextWithOptions(pView.bounds.size, pView.opaque, 0.0);
    [pView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage* img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark- Orientation

- (BOOL)shouldAutorotate
{
    return self.topViewController.shouldAutorotate;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return self.topViewController.supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return self.topViewController.preferredInterfaceOrientationForPresentation;
}

#pragma mark- drag back control

- (void)tempEnableDragBack
{
    if (!_tempEnableDragBack)
    {
        _tempEnableDragBack = YES;
        self.interactivePopGestureRecognizer.enabled = _tempEnableDragBack;
    }
}

- (void)tempDisableDragBack
{
    if (_tempEnableDragBack)
    {
        _tempEnableDragBack = NO;
        self.interactivePopGestureRecognizer.enabled = _tempEnableDragBack;
    }
}

#pragma mark- switch theme
- (void)switchTheme
{
    id vc = [self.viewControllers firstObject];
    if (vc && [vc respondsToSelector:@selector(switchTheme)]){
        [vc switchTheme];
    }
}

#pragma mark- switch language
- (void)switchLanguage
{
    id vc = [self.viewControllers firstObject];
    if (vc && [vc respondsToSelector:@selector(switchLanguage)]){
        [vc switchLanguage];
    }
}

@end
