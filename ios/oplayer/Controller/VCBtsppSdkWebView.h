//
//  VCBtsppSdkWebView.h
//  oplayer
//
//  Created by 夏 胧 on 14-3-25.
//
//

#import "VCBase.h"
#import <WebKit/WebKit.h>

@interface VCBtsppSdkWebView : VCBase<WKNavigationDelegate, WKUIDelegate>

- (id)initWithUrl:(NSString*)url;
- (void)reload;
- (BOOL)goBack;

@end
