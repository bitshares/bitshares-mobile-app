//
//  VCAdDetailInfo.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCAdDetailInfo.h"
#import "NativeAppDelegate.h"

@interface VCAdDetailInfo ()
{
    NSURL*  _ad_url;
    BOOL    _triggered;
}

@end

@implementation VCAdDetailInfo

- (void)dealloc
{
    _ad_url = nil;
}

- (id)initWithUrl:(NSString*)url
{
    self = [super init];
    if (self)
    {
        _ad_url = [[NSURL alloc] initWithString:url];
        _triggered = NO;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    [self showLeftButton:NSLocalizedString(@"kBtnClose", @"关闭") action:@selector(onLeftButtonClick)];
    
    //  加载广告页面
    [self loadRequest:_ad_url];
}

- (void)onLeftButtonClick
{
    //  关闭按钮点击下去之后可能有一些延迟处理，故加标记仅处理一次。
    if (_triggered){
        return;
    }
    _triggered = YES;
    [self closeOrPopViewController];
    [[NativeAppDelegate sharedAppDelegate] closeAdWindow];
}


@end
