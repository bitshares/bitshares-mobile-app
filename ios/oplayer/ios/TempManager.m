//
//  TempManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "TempManager.h"
#import "OrgUtils.h"

#import "AppCommon.h"
#import "MySecurityFileMgr.h"

static TempManager *_sharedTempManager = nil;

@interface TempManager()
{
}
@end

@implementation TempManager

@synthesize favoritesMarketDirty;
@synthesize tickerDataDirty;
@synthesize userLimitOrderDirty;
@synthesize importToWalletDirty;
@synthesize withdrawBalanceDirty;

@synthesize appFirstLaunch;
@synthesize lastEnterBackgroundTs;
@synthesize lastUseHttpProxy;

@synthesize jumpToLoginVC;
@synthesize clearNavbarStackOnVcPushCompleted;

+(TempManager *)sharedTempManager
{
    @synchronized(self)
    {
        if(!_sharedTempManager)
        {
            _sharedTempManager = [[TempManager alloc] init];
        }
        return _sharedTempManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        self.favoritesMarketDirty = NO;
        self.tickerDataDirty = NO;
        self.userLimitOrderDirty = NO;
        self.importToWalletDirty = NO;
        self.withdrawBalanceDirty = NO;
        
        self.appFirstLaunch = NO;
        self.lastEnterBackgroundTs = 0.0f;
        self.lastUseHttpProxy = NO;
        
        self.jumpToLoginVC = NO;
        self.clearNavbarStackOnVcPushCompleted = nil;
    }
    return self;
}

- (void)dealloc
{
    self.favoritesMarketDirty = NO;
    self.tickerDataDirty = NO;
    self.userLimitOrderDirty = NO;
    self.importToWalletDirty = NO;
    self.withdrawBalanceDirty = NO;
    
    self.appFirstLaunch = NO;
    self.lastEnterBackgroundTs = 0.0f;
    self.lastUseHttpProxy = NO;
    
    self.jumpToLoginVC = NO;
    self.clearNavbarStackOnVcPushCompleted = nil;
}

- (void)InitData
{
}

- (void)reset
{
    self.favoritesMarketDirty = NO;
    self.tickerDataDirty = NO;
    self.userLimitOrderDirty = NO;
    self.importToWalletDirty = NO;
    self.withdrawBalanceDirty = NO;
    self.jumpToLoginVC = NO;
}

@end
