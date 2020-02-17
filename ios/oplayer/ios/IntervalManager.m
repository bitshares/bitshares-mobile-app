//
//  IntervalManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "IntervalManager.h"
#import "OrgUtils.h"

static IntervalManager *_sharedIntervalManager = nil;

@interface IntervalManager()
{
    NSMutableDictionary* objLastCallTimestamp;
}
@end

@implementation IntervalManager

+(IntervalManager *)sharedIntervalManager
{
    @synchronized(self)
    {
        if(!_sharedIntervalManager)
        {
            _sharedIntervalManager = [[IntervalManager alloc] init];
        }
        return _sharedIntervalManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        objLastCallTimestamp = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    objLastCallTimestamp = nil;
}

- (void)releaseLock:(id)obj
{
    NSString* obj_hashkey = [NSString stringWithFormat:@"%p", obj];
    [objLastCallTimestamp removeObjectForKey:obj_hashkey];
}

- (void)callBodyWithFixedInterval:(id)obj body:(void (^)())body
{
    //  REMARK：固定时间间隔 ios TableViewCell 大部分动画在 0.2 秒左右。
    //  0.08f － 80毫秒
    [self callBodyWithInterval:obj interval:0.2f body:body];
}

- (void)callBodyWithInterval:(id)obj interval:(NSTimeInterval)interval body:(void (^)())body
{
    NSString* obj_hashkey = [NSString stringWithFormat:@"%p", obj];
    NSTimeInterval nowTs = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval lastCallTs = [[objLastCallTimestamp objectForKey:obj_hashkey] doubleValue];
    if (nowTs >= lastCallTs + interval)
    {
        [objLastCallTimestamp setObject:[NSNumber numberWithDouble:nowTs] forKey:obj_hashkey];
        body();
    }
    else
    {
//        CLS_LOG(@"interval call~ ignore~ ");
    }
}

@end
