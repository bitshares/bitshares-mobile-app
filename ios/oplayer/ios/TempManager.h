//
//  TempManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>

@interface TempManager : NSObject

+ (TempManager*)sharedTempManager;

@property (nonatomic, assign) BOOL favoritesMarketDirty;                //  自选市场是否发生变化，需要重新加载。
@property (nonatomic, assign) BOOL tickerDataDirty;                     //  交易对 ticker 数据有任意一对发生变化就会设置该标记。
@property (nonatomic, assign) BOOL userLimitOrderDirty;                 //  用户限价单信息发生变化，需要重新加载。（交易界面->全部订单管理->取消订单->返回交易界面。）
@property (nonatomic, assign) BOOL importToWalletDirty;                 //  导入账号到已有钱包完成，需要刷新界面。
@property (nonatomic, assign) BOOL withdrawBalanceDirty;                //  提币之后网关列表界面资产余额发生变化，需要刷新。

//  --------- 以上 for fowallet -------

@property (nonatomic, assign) BOOL appFirstLaunch;                      //  App是否是首次运行

@property (nonatomic, assign) NSTimeInterval lastEnterBackgroundTs;     //  记录上次即将进入后台的时间戳，用于从后台返回时判断是否需要进行更新检测。
@property (nonatomic, assign) BOOL lastUseHttpProxy;                    //  进入后台时记录当前是否开启代理标记。
@property (nonatomic, assign) BOOL jumpToLoginVC;                       //  直接跳转到登录vc

//  是否清理导航堆栈（保留首页和当前页面）
@property (weak, nonatomic) UIViewController* clearNavbarStackOnVcPushCompleted;

- (void)InitData;

- (void)reset;

@end
