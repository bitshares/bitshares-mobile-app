//
//  ThemeManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>

#define kAppDefaultThemeCode    @"blue"
#define kAppDefaultThemeName    @"暗黑蓝"  //  TODO:多语言

@interface ThemeManager : NSObject

+ (ThemeManager*)sharedThemeManager;

@property (nonatomic, retain) UIColor* appBackColor;            //  APP最底层背景颜色
@property (nonatomic, retain) UIColor* contentBackColor;        //  内容层背景颜色（比如：navibar、cell）
@property (nonatomic, retain) UIColor* bottomLineColor;         //  TableView等自定义下划线颜色

@property (nonatomic, retain) UIColor* buyColor;                //  买入 上涨颜色
@property (nonatomic, retain) UIColor* sellColor;               //  卖出 下跌颜色
@property (nonatomic, retain) UIColor* zeroColor;               //  +0% 时的颜色
@property (nonatomic, retain) UIColor* callOrderColor;          //  爆仓单颜色

@property (nonatomic, retain) UIColor* textColorPercent;        //  文字颜色：首页涨幅数字颜色
@property (nonatomic, retain) UIColor* textColorHighlight;      //  文字颜色：滑动标题等、主区等醒目颜色
@property (nonatomic, retain) UIColor* textColorGray;           //  文字颜色：/usdt等不明显颜色
@property (nonatomic, retain) UIColor* textColorNormal;         //  文字颜色：24h量等普通颜色
@property (nonatomic, retain) UIColor* textColorMain;           //  文字颜色：数字资产名称、价格等主要颜色

@property (nonatomic, retain) UIColor* ma5Color;                //  移动均线颜色
@property (nonatomic, retain) UIColor* ma10Color;
@property (nonatomic, retain) UIColor* ma30Color;

//  -------------- 以上是 新的 -----------------

@property (nonatomic, retain) UIColor* navigationBarBackColor;  //  导航栏背景颜色
@property (nonatomic, retain) UIColor* navigationBarTextColor;  //  导航栏文字颜色（标题、按钮等）

@property (nonatomic, retain) UIColor* tabBarColor;             //  Tab栏颜色

@property (nonatomic, retain) UIColor* mainButtonBackColor;     //  导航按钮（主）背景颜色（eg: 查询按钮）
@property (nonatomic, retain) UIColor* mainButtonTextColor;     //  导航按钮（主）文字颜色（eg: 查询按钮）
@property (nonatomic, retain) UIColor* blockButtonBackColor;    //  色块按钮（次要）背景颜色（eg: 刷新验证码按钮）
@property (nonatomic, retain) UIColor* blockButtonTextColor;    //  色块按钮（次要）文字颜色（eg: 刷新验证码按钮）
@property (nonatomic, retain) UIColor* frameButtonBorderColor;  //  边框按钮边框颜色（eg: 找回密码按钮）
@property (nonatomic, retain) UIColor* frameButtonTextColor;    //  边框按钮文字颜色（eg: 找回密码按钮）

@property (nonatomic, retain) UIColor* tintColor;               //  Segment、TextField等控件的tintColor
@property (nonatomic, retain) UIColor* iconColor;               //  图标颜色单独设置

@property (nonatomic, retain) UIColor* textColor01;             //  主要文字颜色：UITableViewCell的 label 颜色等
@property (nonatomic, retain) UIColor* textColor02;             //  次要文字颜色：UITableViewCell的 detail 颜色等

@property (nonatomic, retain) UIColor* noticeColor;             //  提醒用户注意的颜色
@property (nonatomic, retain) UIColor* ticketColor;             //  票面颜色

- (NSArray*)getThemeDataArray;
+ (NSDictionary*)getDefaultThemeInfos;
- (void)switchTheme:(NSString*)goalThemeCode reload:(BOOL)reload;
- (void)initThemeFromConfig:(NSArray*)themeList;
//  根据themeCode获取themeName。
- (NSString*)getThemeNameFromThemeCode:(NSString*)themeCode;

+ (UIColor*)genColor:(NSString*)hexstr;
@end
