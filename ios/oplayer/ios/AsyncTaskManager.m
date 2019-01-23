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
    }
    return self;
}

- (void)dealloc
{
}

@end
