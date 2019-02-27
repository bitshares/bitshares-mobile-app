//
//  WsPromise.m
//
//  Created by SYALON on 13-9-3.
//
//

#import "WsPromise.h"
#import <Crashlytics/Crashlytics.h>

@implementation WsPromiseException

+ (void)throwException:(id)error
{
    @throw [self makeException:error];
}

+ (WsPromiseException*)makeException:(id)error
{
    if ([error isKindOfClass:[WsPromiseException class]]){
        return error;
    }else{
        id userinfo = [error isKindOfClass:[NSDictionary class]] ? error : nil;
        return [[WsPromiseException alloc] initWithName:@"WsPromiseRejected" reason:[NSString stringWithFormat:@"%@", error] userInfo:userinfo];
    }
}

@end

static NSInteger __staticPromiseCounter = 0;        //  总的promise计数
static NSInteger __staticPromiseAliveNumber = 0;    //  当前活动的promise计数

@interface WsPromise()
{
    NSInteger           _promise_id;
    WsPromiseState      _state;             //  当前 promise 状态
    
    NSMutableArray*     _resolve_callbacks; //  fulfilled 时的回调
    NSMutableArray*     _reject_callbacks;  //  rejected 时的回调
    
    id                  _value;             //  fulfilled value or rejected value
    NSArray*            _promise_array;     //  保存 all 类型的 promise 的所有子 promise 对象。
}
@end

@implementation WsPromise

@synthesize state = _state;
@synthesize value = _value;
@synthesize once_delegate;

/**
 *  生成已经 resolve 的 promise 对象。
 */
+ (WsPromise*)resolve:(id)data
{
    return [self promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        resolve(data);
    }];
}

/**
 *  生成已经 reject 的 promise 对象。
 */
+ (WsPromise*)reject:(id)data
{
    return [self promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        reject(data);
    }];
}

/**
 *  生成普通的 promise 对象。
 */
+ (WsPromise*)promise:(WsPromiseExecutor)callback
{
    return [[self alloc] initWithHandler:callback];
}

/**
 *  生成 all promise 对象。
 */
+ (WsPromise*)all:(NSArray*)promise_array
{
    return [[self alloc] initWithPromiseArray:promise_array];
}

- (id)initWithPromiseArray:(NSArray*)promise_array
{
    self = [super init];
    if (self)
    {
        _promise_id = ++__staticPromiseCounter;
        ++__staticPromiseAliveNumber;
        
        //  初始化变量
        _state = WsPromiseStatePending;
        _resolve_callbacks = [NSMutableArray array];
        _reject_callbacks = [NSMutableArray array];
        _value = nil;
        _promise_array = [promise_array copy];
        
        //  构造的时候检测 promise 是否已经 fulfilled or rejected
        BOOL fulfilled = YES;
        for (WsPromise* promise in _promise_array){
            //  跳过数组中的null值
            if ([promise isKindOfClass:[NSNull class]]){
                continue;
            }
            if (promise.state == WsPromiseStateRejected){
                //  构造allpromise已经rejected了，则初始化allpromise的状态和值。
                _state = WsPromiseStateRejected;
                _value = promise.value;
                break;
            }else if (promise.state == WsPromiseStatePending){
                fulfilled = NO;
            }
        }
        
        if (_state == WsPromiseStatePending && fulfilled){
            //  构造allpromise已经fulfilled了，则初始化allpromise的状态和值。
            _state = WsPromiseStateFulfilled;
            NSMutableArray* tmp = [NSMutableArray array];
            for (WsPromise* promise in _promise_array){
                if ([promise isKindOfClass:[NSNull class]] || !promise.value){
                    [tmp addObject:[NSNull null]];
                }else{
                    [tmp addObject:promise.value];
                }
            }
            _value = [tmp copy];
        }
        
        //  监听子promise状态变化
        if (_state == WsPromiseStatePending){
            for (WsPromise* promise in _promise_array)
            {
                if ([promise isKindOfClass:[NSNull class]]){
                    continue;
                }
                //  REMARK：修复初始状态就已经 resolve 或 reject 的 promise 对象的 once_delegate 字段不会被设置为 nil，导致 all promise 对象不会释放的问题。
                //  因为 once_delegate 只有在 state_changed 时进行变更，初始化就已经冻结的 promise 不会执行变更处理。
                if (promise.state == WsPromiseStatePending){
                    promise.once_delegate = self;
                }else{
                    promise.once_delegate = nil;
                }
            }
        }
    }
    return self;
}

- (id)initWithHandler:(WsPromiseExecutor)executor
{
    self = [super init];
    if (self)
    {
        _promise_id = ++__staticPromiseCounter;
        ++__staticPromiseAliveNumber;
        
        //  初始化变量
        _state = WsPromiseStatePending;                 //  Promise当前的状态
        _value = nil;                                   //  Promise的值
        _resolve_callbacks = [NSMutableArray array];    //  Promise resolve时的回调函数集，因为在Promise结束之前有可能有多个回调添加到它上面
        _reject_callbacks = [NSMutableArray array];     //  Promise reject时的回调函数集，因为在Promise结束之前有可能有多个回调添加到它上面
        
        _promise_array = nil;
        
        //  执行executor并传入相应的参数
        WsResolveHandler my_self_resolve_handler = ^id(id data){
            [self my_resolve:data];
            return nil; //  这里的返回值忽略
        };
        WsRejectHandler my_self_reject_handler = ^id(id error){
            [self my_reject:error];
            return nil; //  这里的返回值忽略
        };
        //  考虑到执行executor的过程中有可能出错，所以我们用try/catch块给包起来，并且在出错后以catch到的值reject掉这个Promise
        @try {
            executor(my_self_resolve_handler, my_self_reject_handler);
        }
        @catch (WsPromiseException *exception){
            NSLog(@"----catch crash01---%@", exception);
            [self my_reject:exception];
        }
    }
    return self;
}

-(void)dealloc
{
    _resolve_callbacks = nil;
    _reject_callbacks = nil;
    once_delegate = nil;
    if (_promise_array){
        for (WsPromise* promise in _promise_array)
        {
            if ([promise isKindOfClass:[NSNull class]]){
                continue;
            }
            promise.once_delegate = nil;
        }
        _promise_array = nil;
    }
    --__staticPromiseAliveNumber;
    NSLog(@"promise dealloc: %@, alive: %@", @(_promise_id), @(__staticPromiseAliveNumber));
}

/**
 *  (private) then操作核心。public 的 then 和 catch 都是该方法的封装。
 */
- (WsPromise*)then:(WsResolveHandler)onResolved reject:(WsRejectHandler)onRejected
{
    //  根据标准，如果then的参数不是function，则我们需要忽略它。不过这里是 OC 里，强制类型要么为对应类型要么为 nil。
    if (!onResolved)
    {
        onResolved = ^id(id data)
        {
            return data;
        };
    }
    if (!onRejected)
    {
        onRejected = ^id(id data)
        {
            [WsPromiseException throwException:data];
            return nil;
        };
    }
    
    WsPromise* promise_new = nil;
    switch (_state){
        case WsPromiseStateFulfilled:
        {
            //  如果promise1(此处即为this/self)的状态已经确定并且是resolved，我们调用onResolved，因为考虑到有可能throw，所以我们将其包在try/catch块里。
            promise_new = [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject){
                @try {
                    id x = onResolved(_value);
                    if ([x isKindOfClass:[WsPromise class]]){
                        //  如果onResolved的返回值是一个Promise对象，直接取它的结果做为promise2的结果
                        [x then:resolve reject:reject];
                    }else{
                        //  否则，以它的返回值做为promise2的结果
                        resolve(x);
                    }
                }
                @catch (WsPromiseException *exception){
                    //  如果出错，以捕获到的错误做为promise2的结果
                    NSLog(@"----catch crash03---%@", exception);
                    reject(exception);
                }
            }];
        }
            break;
        case WsPromiseStateRejected:
        {
            //  此处 WsPromiseStateFulfilled 的逻辑几乎相同，区别在于所调用的是onRejected函数，就不再做过多解释。
            promise_new = [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject){
                @try {
                    id x = onRejected(_value);
                    if ([x isKindOfClass:[WsPromise class]]){
                        [x then:resolve reject:reject];
                    }else{
                        resolve(x);
                    }
                }
                @catch (WsPromiseException *exception){
                    NSLog(@"----catch crash02---%@", exception);
                    reject(exception);
                }
            }];
        }
            break;
        case WsPromiseStatePending:
        {
            //  如果当前的Promise还处于pending状态，我们并不能确定调用onResolved还是onRejected，
            //  只能等到Promise的状态确定后，才能确实如何处理。
            //  所以我们需要把我们的**两种情况**的处理逻辑做为callback放入promise1(此处即this/self)的回调数组里
            //  逻辑本身跟 WsPromiseStateFulfilled 块内的几乎一致，此处不做过多解释。
            promise_new = [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject){
                WsResolveHandler tempOnResolved = ^id(id data)
                {
                    @try {
                        id x = onResolved(data);    //  REMARK: 这里的参数只能用 data，不能用 _value，否则会导致循环引用，内存泄漏。
                        if ([x isKindOfClass:[WsPromise class]]){
                            [x then:resolve reject:reject];
                        }else{
                            resolve(x);
                        }
                    }
                    @catch (WsPromiseException *exception){
                        NSLog(@"----catch crash04---%@", exception);
                        reject(exception);
                    }
                    return nil;
                };
                WsRejectHandler tempOnRejected = ^id(id data)
                {
                    @try {
                        id x = onRejected(data);    //  REMARK: 这里的参数只能用 data，不能用 _value，否则会导致循环引用，内存泄漏。
                        if ([x isKindOfClass:[WsPromise class]]){
                            [x then:resolve reject:reject];
                        }else{
                            resolve(x);
                        }
                    }
                    @catch (WsPromiseException *exception){
                        NSLog(@"----catch crash05---%@", exception);
                        reject(exception);
                    }
                    return nil;
                };
                [_resolve_callbacks addObject:tempOnResolved];
                [_reject_callbacks addObject:tempOnRejected];
            }];
        }
            break;
        default:
            break;
    }
    return promise_new;
}

/**
 *  (public) then操作
 */
- (WsPromise*)then:(WsResolveHandler)onResolved
{
    return [self then:onResolved reject:nil];
}

/**
 *  (public) catch操作
 */
- (WsPromise*)catch:(WsRejectHandler)onRejected
{
    return [self then:nil reject:onRejected];
}

/**
 *  (private) 完成 promise，状态变更 pending -> fulfilled 。并处理回调。
 */
- (void)my_resolve:(id)data
{
    if (_state != WsPromiseStatePending)
        return;
    
    _value = data;
    [self state_changed:WsPromiseStateFulfilled];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (WsResolveHandler callback in _resolve_callbacks){
            callback(data);
        }
    });
}

/**
 *  (private) 拒绝 promise，状态变更 pending -> rejected 。并处理回调。
 */
- (void)my_reject:(id)error
{
    if (_state != WsPromiseStatePending)
        return;
    
    _value = error;
    [self state_changed:WsPromiseStateRejected];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CLS_LOG(@"my_reject: error: %@", error);
        for (WsRejectHandler callback in _reject_callbacks){
            callback(error);
        }
    });
}

/**
 *  (private) 处理 promise 状态变化
 */
- (void)state_changed:(WsPromiseState)new_state
{
    if (_state == WsPromiseStatePending)
    {
        _state = new_state;
        
        if (self.once_delegate && [self.once_delegate respondsToSelector:@selector(onStateChanged:newState:)])
        {
            [self.once_delegate onStateChanged:self newState:_state];
            
            //  清空代理对象，否则会造成循环引用，两者都没法释放。
            self.once_delegate = nil;
        }
    }
}

/**
 *  (private) 辅助：判断是否指定数组里所有 promise 都完成了。
 */
- (BOOL)allPromiseFulfilled:(NSArray*)promise_array
{
    for (WsPromise* promise in promise_array){
        if ([promise isKindOfClass:[NSNull class]]){
            continue;
        }
        if (promise.state != WsPromiseStateFulfilled){
            return NO;
        }
    }
    return YES;
}

#pragma mark- for WsPromiseDelegate
- (void)onStateChanged:(WsPromise*)promise newState:(WsPromiseState)newState
{
    //  任意一个 promise 被 reject 则 allpromise 失败。
    if (newState == WsPromiseStateRejected){
        [self my_reject:promise.value];
        return;
    }
    
    //  所有 promise 都 fulfilled 则 allpromise 完成。
    if ([self allPromiseFulfilled:_promise_array]){
        NSMutableArray* tmp = [NSMutableArray array];
        for (WsPromise* promise in _promise_array){
            if ([promise isKindOfClass:[NSNull class]] || !promise.value){
                [tmp addObject:[NSNull null]];
            }else{
                [tmp addObject:promise.value];
            }
        }
        [self my_resolve:[tmp copy]];
        return;
    }
}

@end

#pragma mark- WsPromiseObject

@interface WsPromiseObject()
{
    WsPromise*          _promise;
    WsResolveHandler    _resolve_callback;
    WsRejectHandler     _reject_callback;
}
@end

@implementation WsPromiseObject

- (void)dealloc
{
    _resolve_callback = nil;
    _reject_callback = nil;
    _promise = nil;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _promise = [WsPromise promise:(^(WsResolveHandler resolve, WsRejectHandler reject) {
            _resolve_callback = resolve;
            _reject_callback = reject;
        })];
    }
    return self;
}

/**
 *  (public) then操作
 */
- (WsPromise*)then:(WsResolveHandler)onResolved
{
    return [_promise then:onResolved];
}

/**
 *  (public) catch操作
 */
- (WsPromise*)catch:(WsRejectHandler)onRejected
{
    return [_promise catch:onRejected];
}

/**
 * 完成 promise，状态变更 pending -> fulfilled 。并处理回调。
 */
- (void)resolve:(id)data
{
    _resolve_callback(data);
}

/**
 * 拒绝 promise，状态变更 pending -> rejected 。并处理回调。
 */
- (void)reject:(id)error
{
    _reject_callback([WsPromiseException makeException:error]);
}

@end
