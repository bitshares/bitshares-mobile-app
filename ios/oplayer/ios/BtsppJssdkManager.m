//
//  BtsppJssdkManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "BtsppJssdkManager.h"
#import "ChainObjectManager.h"

static BtsppJssdkManager *_sharedBtsppJssdkManager = nil;

@interface BtsppJssdkManager()
{
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
    }
    return self;
}

- (void)dealloc
{
}

- (id)js_call:(NSString*)method args:(id)args
{
    assert(method);
    @try {
        SEL sel = NSSelectorFromString([NSString stringWithFormat:@"%@:", method]);
        if ([self respondsToSelector:sel]) {
            IMP imp = [self methodForSelector:sel];
            assert(imp);
            id (*func_ptr)(id, SEL, id) = (id (*)(id, SEL, id))imp;
            return func_ptr(self, sel, args);
        } else {
            NSLog(@"js call unknown method: %@", method);
            return nil;
        }
    }@catch(NSException* exception){
        NSLog(@"js call error: %@", exception);
        return nil;
    }
}

/*
 *  (public) JSAPI - 根据ID数组查询石墨烯对象。返回 {oid->object, ...} 格式。
 */
- (WsPromise*)query_objects:(NSArray*)oid_array
{
    return [[ChainObjectManager sharedChainObjectManager] queryAllGrapheneObjects:oid_array];
}

@end
