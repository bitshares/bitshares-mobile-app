//
//  BtsppJssdkManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "BtsppJssdkManager.h"
#import "ChainObjectManager.h"
#import "WalletManager.h"

#import "VCBase.h"

static BtsppJssdkManager *_sharedBtsppJssdkManager = nil;

@interface BtsppJssdkManager()
{
    VCBase* _content_vc;            //  当前上下文VC
}
@end

@implementation BtsppJssdkManager

+(BtsppJssdkManager *)sharedBtsppJssdkManager
{
    @synchronized(self)
    {
        if(!_sharedBtsppJssdkManager)
        {
            _sharedBtsppJssdkManager = [[BtsppJssdkManager alloc] init];
        }
        return _sharedBtsppJssdkManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _content_vc = nil;
    }
    return self;
}

- (void)dealloc
{
    [self _clean_data];
}

- (void)_clean_data
{
    _content_vc = nil;
}

- (BtsppJssdkManager*)binding_vc:(VCBase*)vc
{
    _content_vc = vc;
    return self;
}

- (id)js_call:(NSString*)method args:(id)args
{
    assert(method);
    id retv = nil;
    @try {
        SEL sel = NSSelectorFromString([NSString stringWithFormat:@"%@:", method]);
        if ([self respondsToSelector:sel]) {
            IMP imp = [self methodForSelector:sel];
            assert(imp);
            id (*func_ptr)(id, SEL, id) = (id (*)(id, SEL, id))imp;
            retv = func_ptr(self, sel, args);
        } else {
            NSLog(@"js call unknown method: %@", method);
        }
    }@catch(NSException* exception){
        NSLog(@"js call error: %@", exception);
    }
    [self _clean_data];
    return retv;
}

/*
 *  (public) JSAPI - 根据ID数组查询石墨烯对象。返回 {oid->object, ...} 格式。
 */
- (WsPromise*)query_objects:(NSArray*)oid_array
{
    assert(oid_array);
    return [[ChainObjectManager sharedChainObjectManager] queryAllGrapheneObjects:oid_array];
}

- (id)is_wallet_exist:(id)args
{
    return @([[WalletManager sharedWalletManager] isWalletExist]);
}

- (id)show_block_view:(NSString*)msg
{
    if (_content_vc) {
        [_content_vc showBlockViewWithTitle:msg ?: NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    }
    return nil;
}

- (id)hide_block_view:(id)args
{
    if (_content_vc) {
        [_content_vc hideBlockView];
    }
    return nil;
}

- (WsPromise*)tx_transfer:(id)args
{
    //  TODO:
    
    return nil;
}

@end
