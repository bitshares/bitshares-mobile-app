//
//  VCLaunch.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCLaunch.h"
#import "OrgUtils.h"

@interface VCLaunch ()
{
    NSTimer*        _auto_skip_timer;
    BOOL            _triggered;             //  是否已经触发过事件了（转到广告详情界面 or 广告消失）
}

@end

@implementation VCLaunch

- (void)dealloc
{
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _auto_skip_timer = nil;
        _triggered = NO;
    }
    return self;
}

/**
 *  (private) 获取启动界面的图片名
 */
- (NSString*)getLaunchImageName
{
    NSString* viewOrientation = @"Portrait";
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
    {
        viewOrientation = @"Landscape";
    }
    
    CGSize viewSize = [[UIScreen mainScreen] bounds].size;
    for (NSDictionary* dict in [[[NSBundle mainBundle] infoDictionary] valueForKey:@"UILaunchImages"])
    {
        CGSize imageSize = CGSizeFromString(dict[@"UILaunchImageSize"]);
        
        if (CGSizeEqualToSize(imageSize, viewSize) && [viewOrientation isEqualToString:dict[@"UILaunchImageOrientation"]])
        {
            return dict[@"UILaunchImageName"];
        }
    }
    
    return nil;
}

/**
 *  (private) 获取启动界面的图片
 */
- (UIImage*)getLaunchImage
{
    NSString* name = [self getLaunchImageName];
    if (!name){
        return nil;
    }
    return [UIImage imageNamed:name];
}

/**
 *  (private) 裁剪图像
 */
- (UIImage*)clipImage:(CGImageRef)src rect:(CGRect)rect scale:(CGFloat)scale
{
    CGImageRef imageRef = CGImageCreateWithImageInRect(src, rect);
    UIImage* newImage = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(imageRef);
    return newImage;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
  
    UIImage* launchImage = [self getLaunchImage] ?: [UIImage imageNamed:@"LaunchImage"];
    
    UIImageView* launchFullScreenView = [[UIImageView alloc] initWithImage:launchImage];
    launchFullScreenView.frame = screenRect;
    [self.view addSubview:launchFullScreenView];
    
    //  启动定时器
    [self startAutoSkipTimer];
}

- (void)onSkipButtonClick
{
    [self skipAd];
}


- (void)skipAd
{
    //  已经触发过事件了则不再响应点击事件了
    if (_triggered){
        return;
    }
    _triggered = YES;
    [self stopAutoSkipTimer];
    [[NativeAppDelegate sharedAppDelegate] closeLaunchWindow];
}

#pragma mark- ad timer
- (void)startAutoSkipTimer
{
    _auto_skip_timer = [NSTimer scheduledTimerWithTimeInterval:1
                                                        target:self
                                                      selector:@selector(onAutoSkipTimerTick)
                                                      userInfo:nil
                                                       repeats:NO];
}

- (void)stopAutoSkipTimer
{
    if (_auto_skip_timer)
    {
        [_auto_skip_timer invalidate];
        _auto_skip_timer = nil;
    }
}

- (void)onAutoSkipTimerTick
{
    [self skipAd];
}

@end
