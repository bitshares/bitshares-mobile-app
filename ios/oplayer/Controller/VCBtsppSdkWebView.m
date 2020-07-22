//
//  VCBtsppSdkWebView.m
//
//  Created by 夏 胧 on 14-3-25.
//
//

#import "VCBtsppSdkWebView.h"
#import "NJKWebViewProgressView.h"
#import "BtsppJssdkManager.h"
#import "ThemeManager.h"

@interface VCBtsppSdkWebView ()
{
    WKWebView*              _webview;                   //  WebView主体
    NJKWebViewProgressView* _progressView;              //  WebView加载进度条
    
    NSURL*                  _url;                       //  网页的URL
    NSArray*                _back_and_close_buttons;    //  按钮数组
    
    //  REMARK: JSB相关数据
    int64_t                 _jsb_async_callback_id;     //  JSB 异步回调ID
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
        _webview.UIDelegate = nil;
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
        
        _jsb_async_callback_id = 0;
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
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
        
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
    
    //  加载jssdk代码
    NSString* jscode_fullpath = [[NSBundle mainBundle] pathForResource:@"app" ofType:@"js" inDirectory:@"Static"];
    NSString* jscode = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:jscode_fullpath]
                                             encoding:NSUTF8StringEncoding];
    
    //  初始化 WebView 配置文件（加载用户脚本）
    WKUserScript* jscode_user_script = [[WKUserScript alloc] initWithSource:jscode
                                                              injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                           forMainFrameOnly:NO];    //  for all frames
    WKWebViewConfiguration* webview_config = [[WKWebViewConfiguration alloc] init];
    [webview_config.userContentController addUserScript:jscode_user_script];
    
    //  UI - WebView主体
    _webview = [[WKWebView alloc] initWithFrame:[self rectWithoutNavi] configuration:webview_config];
    _webview.navigationDelegate = self;
    _webview.UIDelegate = self;
    _webview.allowsBackForwardNavigationGestures = YES;
    [self.view addSubview:_webview];
    //  监听进度
    [_webview addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [_webview addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionNew context:nil];
    
    //  开始加载 TODO:2.9 临时加载本地
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

#pragma mark - for WKUIDelegate
/*
 *  网页 - 警告框
 */
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    [[UIAlertViewManager sharedUIAlertViewManager] showMessage:message ?: @""
                                                     withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                    completion:^(NSInteger buttonIndex) {
        completionHandler();
    }];
}


/*
 *  网页 - 确认框
 */
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler
{
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:message ?: @""
                                                           withTitle:nil
                                                          completion:^(NSInteger buttonIndex)
     {
        //  0:取消   1:确定
        completionHandler(buttonIndex != 0);
     }];
}

/*
 *  网页 - 输入框
 */
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable result))completionHandler
{
    //  TODO:2.9 magic header
    if (prompt && [prompt rangeOfString:@"__btspp_sdk_call_mode"].location == 0) {
        id call_args = [OrgUtils parse_json:defaultText];
        //  TODO:2.9
        NSString* call_mode = [[prompt substringFromIndex:@"__btspp_sdk_call_mode".length+1] lowercaseString];
        BOOL async_call = [call_mode isEqualToString:@"async"];
        id return_value = [[[BtsppJssdkManager sharedBtsppJssdkManager] binding_vc:self] js_call:[call_args objectForKey:@"mid"]
                                                                                            args:[call_args objectForKey:@"args"]];
        if ([return_value isKindOfClass:[WsPromise class]]) {
            if (async_call) {
                //  1、异步方式调用异步API
                id cid = [self __async_gen_callback_id:completionHandler];
                __weak id this = self;
                [[return_value then:^id(id data) {
                    if (this) {
                        [this __async_return_to_javascript:cid err:nil data:data];
                    }
                    return nil;
                }] catch:^id(id error) {
                    if (this) {
                        //  TODO:error 2.9
                        [this __async_return_to_javascript:cid err:@"query error" data:nil];
                    }
                    return nil;
                }];
            } else {
                //  2、同步方式调用异步API
                __weak id this = self;
                [[return_value then:^id(id data) {
                    if (this) {
                        [this __sync_return_to_javascript:data completionHandler:completionHandler];
                    }
                    return nil;
                }] catch:^id(id error) {
                    if (this) {
                        //  TODO:error 2.9
                        [this __sync_return_to_javascript:nil completionHandler:completionHandler];
                    }
                    return nil;
                }];
            }
        } else {
            if (async_call) {
                //  3、异步方式调用同步API
                id cid = [self __async_gen_callback_id:completionHandler];
                __weak id this = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (this) {
                        [this __async_return_to_javascript:cid err:nil data:return_value];
                    }
                });
            } else {
                //  4、同步调用同步API
                [self __sync_return_to_javascript:return_value completionHandler:completionHandler];
            }
        }
    } else {
        [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:prompt ?: @""
                                                          withTitle:nil
                                                        placeholder:defaultText ?: @""
                                                         ispassword:NO
                                                                 ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                              tfcfg:nil
                                                         completion:^(NSInteger buttonIndex, NSString *tfvalue) {
            if (buttonIndex != 0) {
                //  确定
                completionHandler(tfvalue ?: @"");
            } else {
                //  取消
                completionHandler(nil);
            }
        }];
    }
}

/*
 *  (private) 异步调用方式：生成异步ID，并立即返回给js。后续结果通过callback返回。
 */
- (NSString*)__async_gen_callback_id:(void (^)(NSString * _Nullable result))completionHandler
{
    assert(completionHandler);
    NSString* cid = [NSString stringWithFormat:@"%@", @(++_jsb_async_callback_id)];
    completionHandler(cid);
    return cid;
}

/*
 *  (private) 同步调用方式：返回结果给js。
 */
- (void)__sync_return_to_javascript:(id)data completionHandler:(void (^)(NSString * _Nullable result))completionHandler
{
    assert(completionHandler);
    if (data) {
        completionHandler([data to_json]);
    } else {
        completionHandler(nil);
    }
}

/*
 *  (private) 异步调用方式：返回结果给js。
 */
- (void)__async_return_to_javascript:(NSString*)cid err:(NSString*)err data:(id)data
{
    assert(cid);
    
    id jsb_info = @{@"cid":cid, @"err":err ?: [NSNull null], @"data":data ?: [NSNull null]};
    
    [_webview evaluateJavaScript:[NSString stringWithFormat:@"window.__btspp_jssdk_on_async_callback(%@)", [jsb_info to_json]]
               completionHandler:^(id _Nullable s, NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"invoke js function error: %@", error);
        }
    }];
}

@end
