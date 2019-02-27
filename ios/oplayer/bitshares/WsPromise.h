//
//  WsPromise.h
//  UIDemo
//
//  Created by SYALON on 13-9-3.
//
//  标准：https://promisesaplus.com
//  实现参考：https://zhuanlan.zhihu.com/p/21834559
//  更多参考：https://blog.csdn.net/qq_22844483/article/details/73655738

#import <Foundation/Foundation.h>

/**
 *  声明
 */
@class WsPromise;

/**
 *  各种回调类型定义
 */
typedef id (^WsResolveHandler)(id data);
typedef id (^WsRejectHandler)(id error);
typedef void (^WsPromiseExecutor)(WsResolveHandler resolve, WsRejectHandler reject);

/**
 *  有限状态机
 *  pending为初始状态
 *  fulfilled和rejected为结束状态（结束状态表示promise的生命周期已结束
 *
 *  状态转换关系为：pending->fulfilled，pending->rejected。
 *
 *  - resolve 解决，进入到下一个流程
 *  - reject 拒绝，跳转到捕获异常流程
 */
typedef NS_ENUM(NSInteger, WsPromiseState) {
    WsPromiseStatePending,      //  初始状态
    WsPromiseStateFulfilled,    //  执行成功
    WsPromiseStateRejected      //  执行失败
};

/**
 *  Promise 异常类
 */
@interface WsPromiseException : NSException

/**
 *  (public) 抛出异常
 */
+ (void)throwException:(id)error;

/**
 *  (public) 构造异常
 */
+ (WsPromiseException*)makeException:(id)error;

@end

/**
 *  Promise 代理对象，监听状态变更。
 */
@protocol WsPromiseDelegate <NSObject>
@optional
- (void)onStateChanged:(WsPromise*)promise newState:(WsPromiseState)newState;
@end

/**
 *  Promise 核心对象。
 */
@interface WsPromise : NSObject<WsPromiseDelegate>

@property (nonatomic, assign) WsPromiseState state;
@property (nonatomic, strong) id value;
@property (nonatomic, strong) id<WsPromiseDelegate> once_delegate;      //  该代理用strong引用，不然owner对象会被释放。

+ (WsPromise*)resolve:(id)data;
+ (WsPromise*)reject:(id)data;
+ (WsPromise*)promise:(WsPromiseExecutor)executor;
+ (WsPromise*)all:(NSArray*)promise_array;

- (WsPromise*)then:(WsResolveHandler)onResolved;
- (WsPromise*)catch:(WsRejectHandler)onRejected;

@end

/**
 *  Promise 对象
 */
@interface WsPromiseObject : NSObject

/**
 *  (public) then操作
 */
- (WsPromise*)then:(WsResolveHandler)onResolved;

/**
 *  (public) catch操作
 */
- (WsPromise*)catch:(WsRejectHandler)onRejected;

/**
 * (public) 完成 promise，状态变更 pending -> fulfilled 。并处理回调。
 */
- (void)resolve:(id)data;

/**
 * (public) 拒绝 promise，状态变更 pending -> rejected 。并处理回调。
 */
- (void)reject:(id)error;

@end
