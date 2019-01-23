//
//  VCBtsaiWebView.m
//
//  Created by 夏 胧 on 14-3-25.
//
//

#import "VCBtsaiWebView.h"

@interface VCBtsaiWebView ()
{
    NSURL*                  _custom_url;
    NSArray*                _back_and_close_buttons;
}

@end

@implementation VCBtsaiWebView

- (void)dealloc
{
    _back_and_close_buttons = nil;
    _custom_url = nil;
}

- (id)initWithUrl:(NSString*)url
{
    self = [super init];
    if (self)
    {
        _custom_url = [[NSURL alloc] initWithString:url];
        _back_and_close_buttons = nil;
    }
    return self;
}

- (void)onBarItemBackClick
{
    if (![self goBack])
    {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)onBarItemCloseClick
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onBarItemRefreshClick
{
    [self reload];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //  左边按钮
    UIBarButtonItem* btnClose = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"kBtnClose", @"关闭")
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(onBarItemCloseClick)];
    UIBarButtonItem* btnBack = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"kBtnBack", @"返回")
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(onBarItemBackClick)];
    _back_and_close_buttons = [[NSArray alloc] initWithObjects:btnBack, btnClose, nil];
    
    //  REMARK ios 7 无法拦截ajax请求
    if ([NativeAppDelegate systemVersion] < 8)
    {
        [self.navigationItem setLeftBarButtonItems:_back_and_close_buttons];
    }
    
    //  右边仅显示刷新按钮
    [self showRightButton:NSLocalizedString(@"kBtnRefresh", @"刷新") action:@selector(onBarItemRefreshClick)];
    
    //  开始加载
    [self loadRequest:_custom_url];
}

- (void)onCanGoBackChanged:(BOOL)canGoBack
{
    [super onCanGoBackChanged:canGoBack];
    if (canGoBack)
    {
        [self.navigationItem setLeftBarButtonItems:_back_and_close_buttons];
    }
    else
    {
        [self.navigationItem setLeftBarButtonItems:nil];
    }
}

@end
