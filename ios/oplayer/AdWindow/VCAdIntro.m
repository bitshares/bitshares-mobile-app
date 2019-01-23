//
//  VCAdIntro.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCAdIntro.h"
#import "VCAdDetailInfo.h"
#import "AdManager.h"
#import "OrgUtils.h"

@interface VCAdIntro ()
{
    BOOL            _cfg_add_skip_button;   //  TODO:fowallet 可配置，是否启用跳过按钮
    BOOL            _cfg_add_ad_image;      //  TODO:fowallet 可配置，是否显示广告图片
    
    NSDictionary*   _adInfos;
    NSTimer*        _auto_skip_timer;
    BOOL            _triggered;             //  是否已经触发过事件了（转到广告详情界面 or 广告消失）
}

@end

@implementation VCAdIntro

- (void)dealloc
{
    _adInfos = nil;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _cfg_add_skip_button = NO;
        _cfg_add_ad_image = NO;
        
        _adInfos = nil;
        _auto_skip_timer = nil;
        _triggered = NO;
    }
    return self;
}

- (UIImage*)loadImage:(NSDictionary*)adinfo
{
    NSString* img = [adinfo objectForKey:@"img"];
    if ([[adinfo objectForKey:@"_fromBundle"] boolValue]){
        //  从bundle加载
        return [UIImage imageNamed:img];
    }else{
        //  从缓存加载
        NSString* fullname = [OrgUtils makeFullPathByAdStorage:img];
        return [UIImage imageWithContentsOfFile:fullname];
    }
}

/**
 *  获取启动界面的图片名
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
 *  获取启动界面的图片
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
 *  裁剪图像
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
    
    //  1、广告图片
    if (_cfg_add_ad_image){
        UIImage* image = nil;
        
        //  加载广告最新信息 并 加载对应图片
        NSDictionary* adinfo = [[AdManager sharedAdManager] loadAdInfo];
        if (adinfo){
            image = [self loadImage:adinfo];
        }
        //  加载图片失败则获取默认广告信息
        if (!image){
            adinfo = [[AdManager sharedAdManager] loadDefaultAdInfo];
            image = [self loadImage:adinfo];
        }
        _adInfos = [adinfo copy];
        
        //  广告图片
        UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
        CGFloat realImageH = screenRect.size.width * image.size.height / image.size.width;
        imageView.frame = CGRectMake(0, 0, screenRect.size.width, realImageH);
        [imageView setContentMode:UIViewContentModeScaleAspectFill];
        [self.view addSubview:imageView];
    }

    //  仅广告详情URL存在时才添加点击事件，不存在则不添加。
    NSString* adurl = [_adInfos objectForKey:@"url"];
    if ((adurl && ![adurl isEqualToString:@""]) || [[_adInfos objectForKey:@"_buildin"] integerValue] != kBuildinAd_Invalid){
        UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapped)];
        [self.view addGestureRecognizer:tap];
    }
    
    //  *** 以下代码在底部添加和启动界面相同的Logo（直接从启动界面截取20%高度）
    
    //  logo占屏幕整体高度的百分比
    //  TODO:fowallet 这里可以考虑裁剪
//    CGFloat logoHeightRate = 0.2f;
    CGFloat logoHeightRate = 1.0f;//    REMARK: 不裁剪
    
    UIImage* launchImage = [self getLaunchImage];
    if (launchImage)
    {
        UIImage* adLogoImage;
        if (logoHeightRate >= 1.0f){
            adLogoImage = launchImage;
        }else{
            CGImageRef launchImageRef = [launchImage CGImage];
            size_t cgImageWidth = CGImageGetWidth(launchImageRef);
            size_t cgImageHeight = CGImageGetHeight(launchImageRef);
            CGFloat clipHeight = (int)(cgImageHeight * logoHeightRate);
            adLogoImage = [self clipImage:launchImageRef
                                     rect:CGRectMake(0, cgImageHeight - clipHeight, cgImageWidth, clipHeight)
                                    scale:launchImage.scale];
        }
        UIImageView* logo = [[UIImageView alloc] initWithImage:adLogoImage];
        logo.frame = CGRectMake(0, screenRect.size.height - adLogoImage.size.height, screenRect.size.width, adLogoImage.size.height);
        [self.view addSubview:logo];
    }
    else
    {
        //  REMARK：获取 launch 失败的兼容代码。
        CGFloat logoViewH = (int)(screenRect.size.height * logoHeightRate);
        UIView* logoView = [[UIView alloc] initWithFrame:CGRectMake(0, screenRect.size.height - logoViewH, screenRect.size.width, logoViewH)];
        logoView.backgroundColor = [UIColor whiteColor];
        [self.view addSubview:logoView];
        UIImage* logoImage = [UIImage imageNamed:@"ad_logo"];
        UIImageView* logo = [[UIImageView alloc] initWithImage:logoImage];
        logo.frame = CGRectMake((screenRect.size.width - logoImage.size.width) / 2.0f,
                                (logoViewH - logoImage.size.height) / 2.0f,
                                logoImage.size.width,
                                logoImage.size.height);
        [logoView addSubview:logo];
    }
    
    //  跳过按钮
    if (_cfg_add_skip_button){
        UIButton* skipButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [skipButton setTitle:NSLocalizedString(@"skip", @"跳过") forState:UIControlStateNormal];
        [skipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        skipButton.userInteractionEnabled = YES;
        [skipButton addTarget:self action:@selector(onSkipButtonClick) forControlEvents:UIControlEventTouchUpInside];
        skipButton.layer.borderWidth = 1;
        skipButton.layer.borderColor = [UIColor whiteColor].CGColor;
        skipButton.layer.cornerRadius = 4.0f;
        skipButton.layer.masksToBounds = YES;
        skipButton.layer.opacity = 0.5f;
        skipButton.layer.backgroundColor = [UIColor blackColor].CGColor;
        skipButton.frame = CGRectMake(self.view.bounds.size.width - 60 - 8, 28, 60, 30);
        [self.view addSubview:skipButton];
    }
    
    //  启动定时器
    [self startAutoSkipTimer];
}

- (void)onSkipButtonClick
{
    [self skipAd];
}

- (void)onTapped
{
//    //  已经触发过事件了则不再响应点击事件了
//    if (_triggered){
//        return;
//    }
//    _triggered = YES;
//    [self stopAutoSkipTimer];
//    
//    UIViewController* vc = nil;
//    
//    NSInteger buildinAd_ID = [[_adInfos objectForKey:@"_buildin"] integerValue];
//    switch (buildinAd_ID) {
//        default:
//        {
//            //  默认标题，url加载之后会修改标题。
//            vc = [[VCAdDetailInfo alloc] initWithUrl:[_adInfos objectForKey:@"url"]];
//            vc.title = NSLocalizedString(@"advertisement", @"广告");
//        }
//            break;
//    }
//    
//    vc.hidesBottomBarWhenPushed = YES;
//    [self presentViewController:[[NativeAppDelegate sharedAppDelegate] newNavigationControllerWithoutRelease:vc]
//                       animated:YES
//                     completion:^
//    {
//    }];
}

- (void)skipAd
{
    //  已经触发过事件了则不再响应点击事件了
    if (_triggered){
        return;
    }
    _triggered = YES;
    [self stopAutoSkipTimer];
    [[NativeAppDelegate sharedAppDelegate] closeAdWindow];
}

#pragma mark- ad timer
- (void)startAutoSkipTimer
{
    _auto_skip_timer = [NSTimer scheduledTimerWithTimeInterval:[[_adInfos objectForKey:@"sec"] floatValue]
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
