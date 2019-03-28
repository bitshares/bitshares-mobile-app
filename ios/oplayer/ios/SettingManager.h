//
//  SettingManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//	服务器version文件设置、用户设置相关处理

#import <Foundation/Foundation.h>

#define kSettingKey_EstimateAssetSymbol @"kEstimateAssetSymbol" //  计价单位符号 CNY、USD等
#define kSettingKey_ThemeInfo           @"kThemeInfo"           //  主题风格信息
#define kSettingKey_KLineIndexInfo      @"kKLineIndexInfo_v2"   //  K线指标参数信息    REMARK：如果新增指标需要更新下参数版本

@interface SettingManager : NSObject

+ (SettingManager*)sharedSettingManager;

@property (retain, nonatomic) NSDictionary* serverConfig;   //  所有服务器配置(version.json)

//  是否使用了代理检测
- (BOOL)useHttpProxy;

- (BOOL)isDebuggerAttached;

/**
 *  获取记账单位 CNY、USD 等
 */
- (NSString*)getEstimateAssetSymbol;

/**
 *  获取当前主题风格
 */
- (NSDictionary*)getThemeInfo;

/**
 *  获取K线指标参数配置信息
 */
- (NSDictionary*)getKLineIndexInfos;

//  保存用户配置  kSettingKey_***
- (void)setUseConfig:(NSString*)key value:(BOOL)value;
- (void)setUseConfig:(NSString*)key obj:(id)value;

- (NSString*)getUseConfig:(NSString*)key;

- (NSDictionary*)getAllSetting;

@end
