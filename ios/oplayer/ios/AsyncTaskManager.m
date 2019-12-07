//
//  AsyncTaskManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "AsyncTaskManager.h"

static AsyncTaskManager *_sharedAsyncTaskManager = nil;

@interface AsyncTaskManager()
{
    NSInteger               _seconds_timer_id;
    NSMutableDictionary*    _seconds_timer_hash;
}
@end

@implementation AsyncTaskManager

+(AsyncTaskManager *)sharedAsyncTaskManager
{
    @synchronized(self)
    {
        if(!_sharedAsyncTaskManager)
        {
            _sharedAsyncTaskManager = [[AsyncTaskManager alloc] init];
        }
        return _sharedAsyncTaskManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _seconds_timer_id = 0;
        _seconds_timer_hash = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc
{
    _seconds_timer_hash = nil;
}

/*
 *  (public) 启动按秒的定时器。返回定时器ID号。
 */
- (NSInteger)scheduledSecondsTimer:(NSInteger)max_seconds callback:(AsyncSecondsTimerCallback)callback
{
    assert(max_seconds > 0);
    
    NSInteger startTs = (NSInteger)ceil([[NSDate date] timeIntervalSince1970]);
    NSInteger endTs = startTs + max_seconds;
    
    return [self scheduledSecondsTimerWithEndTS:endTs callback:callback];
}

- (NSInteger)scheduledSecondsTimerWithEndTS:(NSInteger)end_ts callback:(AsyncSecondsTimerCallback)callback
{
    assert(end_ts > 0);
    
    NSInteger tid = ++_seconds_timer_id;
    NSString* timer_id = [NSString stringWithFormat:@"%@", @(tid)];
    id userInfo = @{@"timer_id":timer_id, @"end_ts":@(end_ts), @"callback":[callback copy]};
    
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(_onSecondsTimerTick:)
                                                    userInfo:userInfo
                                                     repeats:YES];
    [_seconds_timer_hash setObject:timer forKey:timer_id];
    
    [timer fire];
    return tid;
}

/*
 *  (public) 定时器是否存在
 */
- (BOOL)isExistSecondsTimer:(NSInteger)tid
{
    if (tid <= 0) {
        return NO;
    }
    return !![_seconds_timer_hash objectForKey:[NSString stringWithFormat:@"%@", @(tid)]];
}

/*
 *  (public) 停止定时器
 */
- (void)removeSecondsTimer:(NSInteger)tid
{
    if (tid > 0) {
        [self _removeSecondsTimerCore:[NSString stringWithFormat:@"%@", @(tid)]];
    }
}

- (void)_removeSecondsTimerCore:(NSString*)timer_id
{
    NSTimer* timer = [_seconds_timer_hash objectForKey:timer_id];
    if (timer) {
        [timer invalidate];
        [_seconds_timer_hash removeObjectForKey:timer_id];
    }
}

- (void)_onSecondsTimerTick:(NSTimer*)timer
{
    assert(timer);
    id userInfo = timer.userInfo;
    assert(userInfo);
    
    NSInteger end_ts = [[userInfo objectForKey:@"end_ts"] integerValue];
    NSInteger now_ts = (NSInteger)ceil([[NSDate date] timeIntervalSince1970]);
    NSInteger left_ts = (NSInteger)(end_ts - now_ts);
    
    AsyncSecondsTimerCallback block = [userInfo objectForKey:@"callback"];
    
    //  回调
    assert(block);
    if (block){
        block(left_ts);
    }
    
    //  结束
    if (left_ts <= 0) {
        [self _removeSecondsTimerCore:[userInfo objectForKey:@"timer_id"]];
    }
}

@end
