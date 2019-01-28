//
//  MainNavController.m
//  oplayer
//
//  Created by SYALON on 13-8-1.
//
//

#import "MyNavigationController.h"
#import "NativeAppDelegate.h"
#import "ViewBackground.h"

@interface MyNavigationController()
{
    BOOL                        _enableDragClose;
    BOOL                        _tempEnableDragBack;    //  临时禁用拖拽返回（比如在显示阻塞界面等情况下）
    
    UIPanGestureRecognizer*     _recognizer;
    CGFloat                     _maxWidth;
    
    ViewBackground*             _backgroundView;
    UIView*                     _blackMask;
    UIImageView*                _lastScreenShotView;
    
    NSMutableArray*             _screenShotList;
    CGPoint                     _startTouch;
    BOOL                        _isMoving;
}

@end

@implementation MyNavigationController

- (void)dealloc
{
    if (_screenShotList)
    {
//        [_screenShotList release];
        _screenShotList = nil;
    }
    
    [self clearBackgroundView];
}

-(void)clearBackgroundView
{
    if (_backgroundView)
    {
        [_lastScreenShotView removeFromSuperview];
        _lastScreenShotView = nil;
        [_backgroundView removeFromSuperview];
        _backgroundView = nil;
    }
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    _tempEnableDragBack = NO;
    _enableDragClose = [NativeAppDelegate systemVersion] < 7;
    
    if (_enableDragClose)
    {
        _maxWidth = [[UIScreen mainScreen] bounds].size.width;
        
        _screenShotList = [[NSMutableArray alloc] init];
        
        _recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(paningGestureReceive:)];
        _recognizer.delaysTouchesBegan = NO;        //  不延迟处理（延迟处理会导致各种点击变的奇怪o.o
        _recognizer.cancelsTouchesInView = YES;     //  响应手势后吞掉事件（向其他view送cancel事件取消处理
        [self.view addGestureRecognizer:_recognizer];
//        [_recognizer release];
        _recognizer.enabled = NO;                   //  默认不启用（只有vc大于1时才启用返回拖拽功能
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (_enableDragClose)
        [_screenShotList addObject:[self capture]];
    
    [super pushViewController:viewController animated:animated];
    
    if (_enableDragClose)
        _recognizer.enabled = _tempEnableDragBack && self.viewControllers.count >= 2;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    if (_enableDragClose)
        [_screenShotList removeLastObject];
    
    UIViewController* pop = [super popViewControllerAnimated:animated];
    
    if (_enableDragClose)
        _recognizer.enabled = _tempEnableDragBack && self.viewControllers.count >= 2;
    
    return pop;
}

/**
 *  获取截屏
 */
- (UIImage *)capture
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

/**
 *  移动到指定x位置
 */
- (void)moveViewWithX:(float)x
{
    x = x > _maxWidth ? _maxWidth : x;
    x = x < 0 ? 0 : x;
    
    CGRect frame = self.view.frame;
    frame.origin.x = x;
    self.view.frame = frame;
    
    float scale = (x * 0.05f / _maxWidth) + 0.95f;
    float alpha = 0.4f - (x * 0.4f / _maxWidth);
    
    _lastScreenShotView.transform = CGAffineTransformMakeScale(scale, scale);
    _blackMask.alpha = alpha;
}

#pragma mark - Gesture Recognizer -

/**
 *  移动到目标位置
 */
- (void)animationMoveToTarget
{
    [UIView animateWithDuration:0.3 animations:^{
        [self moveViewWithX:_maxWidth];
    } completion:^(BOOL finished) {
        [self popViewControllerAnimated:NO];
        
        CGRect frame = self.view.frame;
        frame.origin.x = 0;
        self.view.frame = frame;
        
        _isMoving = NO;
    }];
}

/**
 *  移动到原来位置
 */
- (void)animationMoveToOrigin
{
    [UIView animateWithDuration:0.3 animations:^{
        [self moveViewWithX:0];
    } completion:^(BOOL finished) {
        _isMoving = NO;
        _backgroundView.hidden = YES;
    }];
}

- (void)paningGestureReceive:(UIPanGestureRecognizer *)recoginzer
{
    //  顶层视图直接返回
    if (self.viewControllers.count <= 1)
        return;
    
    //  获取坐标
    CGPoint touchPoint = [recoginzer locationInView:[[UIApplication sharedApplication] keyWindow]];
    
    ///<    开始拖拽
    if (recoginzer.state == UIGestureRecognizerStateBegan) {
        
        _isMoving = YES;
        _startTouch = touchPoint;
        
        ///<    背景视图              > 当前视图
        ///<    上个视图的截屏 > 暗视图 > 当前视图
        
        if (!_backgroundView)
        {
            CGRect frame = self.view.frame;
            
            _backgroundView = [[ViewBackground alloc] initWithFrame:frame owner:self];
            [self.view.superview insertSubview:_backgroundView belowSubview:self.view];
//            [_backgroundView release];
            
            _blackMask = [[UIView alloc] initWithFrame:frame];
            _blackMask.backgroundColor = [UIColor blackColor];
            [_backgroundView addSubview:_blackMask];
//            [_blackMask release];
        }
        _backgroundView.hidden = NO;
        
        if (_lastScreenShotView)
            [_lastScreenShotView removeFromSuperview];
        _lastScreenShotView = [[UIImageView alloc] initWithImage:[_screenShotList lastObject]];
        [_backgroundView insertSubview:_lastScreenShotView belowSubview:_blackMask];
//        [_lastScreenShotView release];
        
        [self onDragBackStart];
    ///<    拖拽结束（返回or复原）
    }else if (recoginzer.state == UIGestureRecognizerStateEnded){
        
        if (touchPoint.x - _startTouch.x > _maxWidth * 0.156f)
        {
            [self animationMoveToTarget];
            [self onDragBackFinish:YES];
        }
        else
        {
            [self animationMoveToOrigin];
            [self onDragBackFinish:NO];
        }
        return;
    ///<    拖拽取消
    }else if (recoginzer.state == UIGestureRecognizerStateCancelled){
        [self animationMoveToOrigin];
        [self onDragBackFinish:NO];
        return;
    }
    
    ///<    拖拽中
    if (_isMoving) {
        [self moveViewWithX:touchPoint.x - _startTouch.x];
    }
}

#pragma mark- drag back event

- (void)onDragBackStart
{
    UIViewController* vc = self.topViewController;
    if (vc && [vc respondsToSelector:@selector(onDragBackStart)])
    {
        [(id)vc onDragBackStart];
    }
}

- (void)onDragBackFinish:(BOOL)bToTarget
{
    UIViewController* vc = self.topViewController;
    if (vc && [vc respondsToSelector:@selector(onDragBackFinish:)])
    {
        [(id)vc onDragBackFinish:bToTarget];
    }
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
        if ([NativeAppDelegate systemVersion] < 7)
        {
            _recognizer.enabled = _tempEnableDragBack && self.viewControllers.count >= 2;
        }
        else
        {
            self.interactivePopGestureRecognizer.enabled = _tempEnableDragBack;
        }
    }
}

- (void)tempDisableDragBack
{
    if (_tempEnableDragBack)
    {
        _tempEnableDragBack = NO;
        if ([NativeAppDelegate systemVersion] < 7)
        {
            _recognizer.enabled = _tempEnableDragBack && self.viewControllers.count >= 2;
        }
        else
        {
            self.interactivePopGestureRecognizer.enabled = _tempEnableDragBack;
        }
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
