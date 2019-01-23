//
//  VCBaseWebView.h
//  oplayer
//
//  Created by SYALON on 14-3-25.
//
//

#import "VCBase.h"
#import <WebKit/WebKit.h>
#import "NJKWebViewProgress.h"

@interface VCBaseWebView : VCBase<UIWebViewDelegate, WKNavigationDelegate, NJKWebViewProgressDelegate>

- (id)initWithDefaultURL:(NSURL*)url;
- (void)loadRequest:(NSURL*)url;
- (void)reload;
- (BOOL)goBack;

- (void)onCanGoBackChanged:(BOOL)canGoBack;

@end
