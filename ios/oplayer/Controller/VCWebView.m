//
//  VCWebView.m
//
//  Created by SYALON on 14-3-25.
//
//

#import "VCWebView.h"

/**
 *  按钮
 */
enum
{
    kTagButtonGoBack = 100,
    kTagButtonGoForward,
    kTagButtonRefresh,
    
    kTagButtonMax
};

@interface VCWebView ()
{
    NSURL*                      _url;
    
    UIWebView*                  _webview;
    
    UIBarButtonItem*            _btnGoBack;
    UIBarButtonItem*            _btnGoForward;
    UIBarButtonItem*            _btnRefresh;
}

@end

@implementation VCWebView

- (void)dealloc
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    _webview.delegate = nil;
    [_webview stopLoading];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithURL:(NSString*)url
{
    self = [super init];
    if (self)
    {
        _url = [[NSURL alloc] initWithString:url];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    //  网页
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    self.automaticallyAdjustsScrollViewInsets = NO;
    _webview = [[UIWebView alloc] initWithFrame:[self rectWithoutNaviAndTool]];
    _webview.delegate = self;
    _webview.scalesPageToFit = YES;
    [self.view addSubview:_webview];
    
    //  导航栏
    UIToolbar* toolbarView;
    toolbarView = [[UIToolbar alloc] initWithFrame:CGRectMake(0, screenRect.size.height - [self heightForStatusAndNaviBar] - [self heightForToolBar],
                                                              screenRect.size.width, [self heightForToolBar])];
    [self.view addSubview:toolbarView];
    toolbarView.tintColor = [UIColor whiteColor];
    toolbarView.translucent = NO;
    toolbarView.barTintColor = [ThemeManager sharedThemeManager].tintColor;
    toolbarView.backgroundColor = [ThemeManager sharedThemeManager].tintColor;
    
    //  布局用
    UIBarButtonItem* flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    //  各种按钮
    _btnGoBack = [[UIBarButtonItem alloc] initWithImage:[UIImage templateImageNamed:@"Back-44"] style:UIBarButtonItemStylePlain target:self action:@selector(onBarItemClick:)];
    
    _btnGoBack.tag = kTagButtonGoBack;
    _btnGoForward = [[UIBarButtonItem alloc] initWithImage:[UIImage templateImageNamed:@"Forward-44"] style:UIBarButtonItemStylePlain target:self action:@selector(onBarItemClick:)];
    
    _btnGoForward.tag = kTagButtonGoForward;
    _btnRefresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(onBarItemClick:)];
    _btnRefresh.tag = kTagButtonRefresh;

    //  设置导航栏
    [toolbarView setItems:[NSArray arrayWithObjects:_btnGoBack,flexible,_btnGoForward,  flexible, flexible, flexible,_btnRefresh, nil] animated:YES];
    
    _btnGoBack.enabled = NO;
    _btnGoForward.enabled = NO;
    
    //  开始加载
    [_webview loadRequest:[NSURLRequest requestWithURL:_url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:3600]];
}

- (void)onBarItemClick:(UIBarButtonItem*)sender
{
    switch (sender.tag) {
        case kTagButtonGoBack:
            [_webview goBack];
            break;
        case kTagButtonGoForward:
            [_webview goForward];
            break;
        case kTagButtonRefresh:
            [_webview reload];
            break;
        default:
            break;
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark- UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    _btnGoBack.enabled = [_webview canGoBack];
    _btnGoForward.enabled = [_webview canGoForward];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    _btnGoBack.enabled = NO;
    _btnGoForward.enabled = NO;
}

@end
