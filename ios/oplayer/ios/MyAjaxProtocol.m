//
//  MyAjaxProtocol.m
//  oplayer
//
//  Created by SYALON on 14-1-4.
//
//

#import "MyAjaxProtocol.h"
#import "NativeMethodExtension.h"
#import "AFNetworking.h"
#import "SettingManager.h"
#import "Crashlytics/Crashlytics.h"

@interface MyAjaxProtocol()

@property (nonatomic, strong) NSURLSessionDataTask* task;

@end

static AFURLSessionManager *_manager = nil;

@implementation MyAjaxProtocol

-(AFURLSessionManager*) manager
{
    @synchronized(self)
    {
        if(!_manager)
        {
            NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
            AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:config];
            manager.responseSerializer = [AFHTTPResponseSerializer serializer];
            // 安全验证
            AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode: AFSSLPinningModeNone];
            securityPolicy.allowInvalidCertificates = YES;
            securityPolicy.validatesDomainName = NO;
            manager.securityPolicy = securityPolicy;
            _manager = manager;
        }
        return _manager;
    }
}

#pragma mark- NSURLProtocol method

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    //  ...
    return NO;
}

+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSLog(@"startLoading %@",[self request].URL);
    NSString* host = [self request].URL.host;
    NSString* custom_ua = [[self request] valueForHTTPHeaderField:@"_ua"];
    NSString* custom_origin = [[self request] valueForHTTPHeaderField:@"_origin"];
    
    //  没有 _ua 的情况下检测域名，设置对应的默认值。
    if (!custom_ua || [custom_ua isEqualToString:@""])
    {
        //  ...
    }
    
    //  构造新的请求（如果不设置 ua 和 origin 则直接拷贝，否则自己构造一个请求。）
    NSMutableURLRequest* newRequest;
    
    if (custom_ua || custom_origin)
    {
        //  REMARK：构造新的请求，确保和之前的一致。
        newRequest = [[NSMutableURLRequest alloc] initWithURL:[self request].URL];
        [newRequest setHTTPBody:self.request.HTTPBody];
        [newRequest setHTTPMethod:self.request.HTTPMethod];
        [newRequest setCachePolicy:self.request.cachePolicy];
        [newRequest setTimeoutInterval:self.request.timeoutInterval];
        [newRequest setAllowsCellularAccess:self.request.allowsCellularAccess];
        [newRequest setNetworkServiceType:self.request.networkServiceType];
        [newRequest setMainDocumentURL:self.request.mainDocumentURL];
    }
    else
    {
        //  拷贝请求
        newRequest = [[self request] mutableCopy];
    }
    
    //  构造新的 headers（忽略 _ua、_origin）
    NSMutableDictionary* newHeaders = [NSMutableDictionary dictionary];
    [[self.request allHTTPHeaderFields] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (![key isEqualToString:@"_ua"]
            && ![key isEqualToString:@"_origin"]
            && ![key isEqualToString:@"Origin"])
        {
            [newHeaders setObject:obj forKey:key];
        }
    }];
    
    //  设置自定义 ua 和 origin
    if (custom_ua && ![custom_ua isEqualToString:@""])
    {
        [newHeaders setObject:custom_ua forKey:@"User-Agent"];
    }
    if (custom_origin && ![custom_origin isEqualToString:@""])
    {
        [newHeaders setObject:custom_origin forKey:@"Origin"];
    }
    
    //  设置新的 header
    [newRequest setAllHTTPHeaderFields:newHeaders];
    
    NSLog(@">>>all headers<<<<\n%@", [newRequest allHTTPHeaderFields]);
    
    //  设置标记
    [NSURLProtocol setProperty:@YES forKey:@"__myhookpass__" inRequest:newRequest];
    
    //  DEBUG版本不验证
    NSTimeInterval taskStartRequestTS = -1;
    AFURLSessionManager *theManager = [self manager];
    __block BOOL taskResponsed = NO;
    self.task = [theManager dataTaskWithRequest:newRequest completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        //  DEBUG: TODO：是否两次响应检测
        if (taskResponsed){
//            CLS_LOG(@"NetworkError double responsed...");
        }
        taskResponsed = YES;
        
        //  请求开始的时间戳不为负数则check是否达到重置时间
        if (taskStartRequestTS >= 0){
            if ([[NSDate date] timeIntervalSince1970] - taskStartRequestTS >= 4.0f){
//                CLS_LOG(@"Network Too Slow, reset session manager at next request...");
            }
        }
        
        //  REMARK：如果是被取消，则什么都不处理。如果继续回调 didFailWithError 则会触发两次响应。参考，搜索关键字：Error Domain=NSURLErrorDomain Code=-999
        if (error && [error code] == NSURLErrorCancelled){
//            CLS_LOG("NetworkError NSURLErrorCancelled");
            return;
        }
        
        NSLog(@"response %@ responseObject %@ error %@",NSStringFromClass([response classForCoder]), NSStringFromClass([responseObject classForCoder]), error);
        if (![response isKindOfClass:[NSHTTPURLResponse class]] || (responseObject && ![responseObject isKindOfClass:[NSData class]]))
        {
//            CLS_LOG(@"response %@ responseObject %@ error %@",NSStringFromClass([response classForCoder]), NSStringFromClass([responseObject classForCoder]), error);
        }
        //  REMARK：这个error和NSURLSession代理中出现的error不同，这个仅仅是AF decode 原始数据产生的错误。
        if(error)
        {
//            CLS_LOG(@"NetworkError response %@ responseObject %@ error %@",NSStringFromClass([response classForCoder]), NSStringFromClass([responseObject classForCoder]), error);
            NSLog(@"NetworkError response %@ responseObject %@ error %@",NSStringFromClass([response classForCoder]), NSStringFromClass([responseObject classForCoder]), error);
        }
        if (!response || !responseObject)
        {
            [self.client URLProtocol:self didFailWithError:error];
        }else
        {
            //  write cookie
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse *)response;
            NSDictionary *allHeader = [httpResponse allHeaderFields];
            NSURL *url = self.request.URL;
            NSArray* cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:allHeader forURL:url];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:cookies forURL:self.request.URL mainDocumentURL:nil];
            
            //  分发响应
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
            
            [self.client URLProtocol:self didLoadData:responseObject];
            [self.client URLProtocolDidFinishLoading:self];
        }
    }];
    [self.task resume];
}

- (void)stopLoading
{
    NSLog(@"stopLoading...");
    if (self.task){
        [self.task cancel];
        self.task = nil;
    }
}

@end
