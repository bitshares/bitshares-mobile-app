//
//  VCBtsppSdkWebView.m
//
//  Created by 夏 胧 on 14-3-25.
//
//

#import "VCBtsppSdkWebView.h"
#import <WebKit/WebKit.h>
#import "NJKWebViewProgressView.h"
#import "ThemeManager.h"

@interface VCBtsppSdkWebView ()
{
    WKWebView*              _webview;               //  WebView主体
    NJKWebViewProgressView* _progressView;          //  WebView加载进度条
    
    NSURL*                  _url;                   //  网页的URL
    NSArray*                _back_and_close_buttons;//  按钮数组
}

@end

@implementation VCBtsppSdkWebView

- (void)dealloc
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    _progressView = nil;
    if (_webview)
    {
        //  移除观察者，不移除会崩溃。
        [_webview removeObserver:self forKeyPath:@"estimatedProgress"];
        [_webview removeObserver:self forKeyPath:@"canGoBack"];
        _webview.navigationDelegate = nil;
        [_webview stopLoading];
        _webview = nil;
    }
    _back_and_close_buttons = nil;
    _url = nil;
}

- (id)initWithUrl:(NSString*)url
{
    self = [super init];
    if (self)
    {
        _webview = nil;
        _progressView = nil;
        _url = [[NSURL alloc] initWithString:url];
        _back_and_close_buttons = nil;
    }
    return self;
}

/*
 *  (private) 加载请求
 */
- (void)_loadRequest:(NSURL*)url
{
    if (url && _webview)
    {
        [_webview loadRequest:[NSURLRequest requestWithURL:url]];
    }
}

/*
 *  (public) 刷新
 */
- (void)reload
{
    if (_webview)
    {
        [_webview reload];
    }
}

/*
 *  (public) 回退（如果回退了则返回true，否则返回false。
 */
- (BOOL)goBack
{
    if (_webview && [_webview canGoBack])
    {
        [_webview goBack];
        return YES;
    }
    else
    {
        return NO;
    }
}

/*
 *  (private) 导航栏左边按钮 - 返回
 */
- (void)onBarItemBackClick
{
    if (![self goBack])
    {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

/*
*  (private) 导航栏左边按钮 - 关闭
*/
- (void)onBarItemCloseClick
{
    [self.navigationController popViewControllerAnimated:YES];
}

/*
*  (private) 导航栏右边按钮 - 刷新
*/
- (void)onBarItemRefreshClick
{
    [self reload];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
        
    //  UI - 导航栏左边按钮
    UIBarButtonItem* btnClose = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"kBtnClose", @"关闭")
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(onBarItemCloseClick)];
    UIBarButtonItem* btnBack = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"kBtnBack", @"返回")
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(onBarItemBackClick)];
    _back_and_close_buttons = [[NSArray alloc] initWithObjects:btnBack, btnClose, nil];
    
    //  UI - 导航栏右边刷新按钮
    [self showRightButton:NSLocalizedString(@"kBtnRefresh", @"刷新") action:@selector(onBarItemRefreshClick)];
    
    //  UI - 网页加载进度条
    CGFloat progressBarHeight = 2.f;
    CGRect navigationBarBounds = self.navigationController.navigationBar.bounds;
    CGRect barFrame = CGRectMake(0, navigationBarBounds.size.height - progressBarHeight,
                                 navigationBarBounds.size.width, progressBarHeight);
    _progressView = [[NJKWebViewProgressView alloc] initWithFrame:barFrame];
    _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    //  REMARK：进度条使用mainbutton的颜色
    _progressView.progressBarView.backgroundColor = [ThemeManager sharedThemeManager].mainButtonBackColor;
    
    //  UI - WebView主体
    _webview = [[WKWebView alloc] initWithFrame:[self rectWithoutNavi]];
    _webview.navigationDelegate = self;
    _webview.allowsBackForwardNavigationGestures = YES;
    [self.view addSubview:_webview];
    //  监听进度
    [_webview addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [_webview addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionNew context:nil];
    
    //  开始加载
    [self _loadRequest:_url];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController.navigationBar addSubview:_progressView];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // remove progress view. because UINavigationBar is shared with other ViewControllers.
    [_progressView removeFromSuperview];
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    //  self.navigationItem.title = webView.title;    //  REMARK：可动态切换标题
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

#pragma mark- watch WKWebView load progress...
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (keyPath && object == _webview)
    {
        if ([keyPath isEqualToString:@"estimatedProgress"])
        {
            [_progressView setProgress:_webview.estimatedProgress animated:YES];
        }
        else if ([keyPath isEqualToString:@"canGoBack"])
        {
            [self _onCanGoBackChanged:_webview.canGoBack];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)_onCanGoBackChanged:(BOOL)canGoBack
{
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
