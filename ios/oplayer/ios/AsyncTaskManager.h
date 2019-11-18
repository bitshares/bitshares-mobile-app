//
//  AsyncTaskManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//  部分异步任务管理器。

#import <Foundation/Foundation.h>

typedef void (^AsyncSecondsTimerCallback)(NSInteger left_ts);

@interface AsyncTaskManager : NSObject

+ (AsyncTaskManager*)sharedAsyncTaskManager;

/*
 *  (public) 启动按秒的定时器。返回定时器ID号。
 */
- (NSInteger)scheduledSecondsTimer:(NSInteger)max_seconds callback:(AsyncSecondsTimerCallback)callback;
- (NSInteger)scheduledSecondsTimerWithEndTS:(NSInteger)end_ts callback:(AsyncSecondsTimerCallback)callback;

/*
 *  (public) 定时器是否存在
 */
- (BOOL)isExistSecondsTimer:(NSInteger)tid;

/*
 *  (public) 停止定时器
 */
- (void)removeSecondsTimer:(NSInteger)tid;

@end
