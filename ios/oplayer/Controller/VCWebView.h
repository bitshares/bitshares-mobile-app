//
//  VCWebView.h
//  oplayer
//
//  Created by SYALON on 14-3-25.
//
//

#import "VCBase.h"

@interface VCWebView : VCBase<UIWebViewDelegate>

- (id)initWithURL:(NSString*)url;

@end
