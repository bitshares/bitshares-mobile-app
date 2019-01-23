//
//  VCFirstLaunch.m
//  oplayer
//
//  Created by SYALON on 13-11-13.
//
//

#import "VCFirstLaunch.h"
#import "NativeAppDelegate.h"
#import "AppCacheManager.h"
#import "ViewEnterApp.h"
#import "ThemeManager.h"

@interface VCFirstLaunch ()
{
    RecommendScrollCell* _bannerView;
}

@end

@implementation VCFirstLaunch

- (void)dealloc
{
    if (_bannerView){
        _bannerView.delegate = nil;
        _bannerView = nil;
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
//    ViewEnterApp* viewFirst = [[ViewEnterApp alloc] initWithFrame:screenRect owner:self];
    UIImageView* image1 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"first1"]];
    UIImageView* image2 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"first2"]];
    ViewEnterApp* image3 = [[ViewEnterApp alloc] initWithFrame:screenRect owner:self];
//    UIImageView* viewLast = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"first1"]];
    
    [image1 setContentMode:UIViewContentModeScaleAspectFill];
    [image2 setContentMode:UIViewContentModeScaleAspectFill];
//    [viewLast setContentMode:UIViewContentModeScaleAspectFill];
    
    NSArray* viewArray = [NSArray arrayWithObjects:image1, image2, image3, nil];
    
    _bannerView = [[RecommendScrollCell alloc] initWithFrame:screenRect delegate:self imageItems:viewArray isAuto:NO];
    [self.view addSubview:_bannerView];
    
    //  跳过按钮
    UIButton* skipButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [skipButton setTitle:NSLocalizedString(@"skip", @"跳过") forState:UIControlStateNormal];
    [skipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    skipButton.userInteractionEnabled = YES;
    [skipButton addTarget:self action:@selector(onSkipButtonClick) forControlEvents:UIControlEventTouchUpInside];
    skipButton.layer.borderWidth = 1;
    skipButton.layer.borderColor = [ThemeManager sharedThemeManager].textColorHighlight.CGColor;
    skipButton.layer.cornerRadius = 3.0f;
    skipButton.layer.masksToBounds = YES;
    skipButton.layer.opacity = 0.5f;
    skipButton.layer.backgroundColor = [ThemeManager sharedThemeManager].textColorGray.CGColor;
    skipButton.frame = CGRectMake(self.view.bounds.size.width - 60 - 8, 28, 60, 30);
    [self.view addSubview:skipButton];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onSkipButtonClick
{
    //  [统计]
    [Answers logCustomEventWithName:@"buttonEvents" customAttributes:@{@"kind":@"firstIntroSkip"}];
    [self enterAppCore];
}

- (void)enterApp
{
    //  [统计]
    [Answers logCustomEventWithName:@"buttonEvents" customAttributes:@{@"kind":@"firstIntroEnter"}];
    [self enterAppCore];
}

- (void)enterAppCore
{
    //  set firstrun flag
    [[AppCacheManager sharedAppCacheManager] saveFirstRunWithVersion:[NativeAppDelegate appShortVersion]];
    
    //  enter
    [[NativeAppDelegate sharedAppDelegate] enter];
}

@end
