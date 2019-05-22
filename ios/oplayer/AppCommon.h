//
//  AppCommon.h
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#ifndef oplayer_AppCommon_h
#define oplayer_AppCommon_h

//  渠道ID编号（0:iOS企业版 1:AppStore 10:android官方版）
#if APPSTORE_CHANNEL
#define kAppChannelID                       1
#else
#define kAppChannelID                       0
#endif  //  APPSTORE_CHANNEL

//  【系统通知】网络重连成功后发送
#define kBtsWebsocketReconnectSuccess       @"kBtsWebsocketReconnectSuccess"

//  BTS 对象本地缓存过期时间
#define kBTSObjectCacheExpireTime           86400

//  UI - 部分参数配置
#define kUITableViewLeftEdge                12.0f       //  左边距

//  配置：[默认值]

//  UI - 用户资产 默认显示数量（多余的资产不显示）
#define kAppUserAssetDefaultShowNum         10

//  UI - 用户资产 默认估值基础计价资产
#define kAppUserAssetCoreEstimateAsset      @"CNY"

//  [App内部目录] App自带的Static目录（里面包含version、jsapi等）
#define kAppStaticDir                       @"Static"

//  [App内部目录] App自带的静态数据目录
#define kAppStaticDataDir                   @"Static/Data"

//  [by ver] App自带的静态数据更新后缓存中的目录 /AppCache/ver/#{curr_version}_#{kAppDataCacheDir}/filename
#define kAppDataCacheDir                    @"data"

//  [by app] 导入的钱包bin文件缓存目录 /AppCache/app/wbin/#{binfilename}
#define kAppWalletBinFileDir                @"wbin"

//  [by app] 广告图片缓存目录 /AppCache/app/ad/#{adimagename}
#define kAppAdImageDir                      @"ad"

//  [by ver] App数据的版本信息文件
#define kAppStaticDataVersionInfoFile       @"data.json"

//  软件：本地文件最终路径：
//  1、/AppCache/ver/#{curr_version}_filename
//  2、/AppCache/app/filename
//  软件：本地写入文件根目录
#define kAppLocalFileNameBase               @"AppCache"
//  软件：本地当前版本依赖文件写入目录
#define kAppLocalFileNameByVerStorage       @"ver"
//  软件：本地app依赖文件写入目录（跨所有版本）
#define kAppLocalFileNameByAppStorage       @"app"

//  by ver
#define kAppCacheNameJsRuntimeCoreByVer     @"jscore.js"
#define kAppCacheNameJsRuntimeByVer         @"jsvers.json"
#define kAppCacheNameDataVerByVer           @"dver.json"
#define kAppCacheNameVersionJsonByVer       @"version.json"

//  by app （REMARK：在忘记锁屏密码重置app时候以下5个全部删除）
#define kAppCacheNameWalletInfoByApp        @"wallet_v1.json"
#define kAppCacheNameObjectCacheByApp       @"object_v1.json"
#define kAppCacheNameFavAccountsByApp       @"favaccounts_v1.json"
#define kAppCacheNameFavMarketsByApp        @"favmarkets_v1.json"
#define kAppCacheNameCustomMarketsByApp     @"custommarkets_v1.json"
#define kAppCacheNameUserSettingByApp       @"usersetting_v1.json"
#define kAppCacheNameMemoryInfosByApp       @"memory_v1.json"

//  默认系统字体
#define kAppDefaultSystemFontName           @"Helvetica"

//  UITableViewCell 中的 UITextField 宽度占屏幕宽度的百分比。
#define kAppTextFieldWidthFactor            0.70f

//  从后台回到前台，超过该时间则检测更新。
#if TEST_UPDATE
#define kBackToForegroundCheckupdateTimespace   1.0f
#else
#define kBackToForegroundCheckupdateTimespace   3600.0f
#endif //TEST_UPDATE

//  事件
#define kNoticeOnModelViewControllerClosed  @"kNoticeOnModelViewControllerClosed"

//  vc 导航：默认返回按钮名字
#define kVcDefaultBackTitleName             NSLocalizedString(@"kBtnBack", @"返回")

//  引入头文件
#import "NativeMethodExtension.h"

#endif
