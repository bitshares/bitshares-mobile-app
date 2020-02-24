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
    _disablePopGesture = NO;
//    self.interactivePopGestureRecognizer.delegate = self;
//    [self.interactivePopGestureRecognizer requireGestureRecognizerToFail:nil];
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

/*
 *  (public) 启用/禁用 拖拽返回上一个界面。
 */
- (void)tempEnableDragBack
{
    if (!_tempEnableDragBack)
    {
        _tempEnableDragBack = YES;
        self.interactivePopGestureRecognizer.enabled = _tempEnableDragBack && !_disablePopGesture;
    }
}

- (void)tempDisableDragBack
{
    if (_tempEnableDragBack)
    {
        _tempEnableDragBack = NO;
        self.interactivePopGestureRecognizer.enabled = _tempEnableDragBack && !_disablePopGesture;
    }
}

- (void)setDisablePopGesture:(BOOL)value
{
    _disablePopGesture = value;
    self.interactivePopGestureRecognizer.enabled = _tempEnableDragBack && !_disablePopGesture;
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

//-(BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceiveTouch:(UITouch*)touch {
//
////    if ([touch.view isKindOfClass:[UISlider class]]) {
////        return NO;
////    }
//
//    return YES;
//}

@end
