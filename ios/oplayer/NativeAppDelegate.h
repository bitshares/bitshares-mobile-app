//
//  NativeAppDelegate.h
//  oplayer
//
//  Created by SYALON on 13-8-1.
//
//

#import <UIKit/UIKit.h>
#import "Reachability.h"
#import "AppCommon.h"

@class MyNavigationController;

@interface NativeAppDelegate : UIResponder <UIApplicationDelegate>
{
    UITabBarController*     _mainTabController;
    
    NSString*               _currLanguage;
    NetworkStatus           _currNetStatus;
    Reachability*           _reach;
}

+(BOOL)isJailbroken;
+(NSString*)deviceDetailDescription;
+(NSString*)getSystemLanguage;
+(NSString*)deviceUniqueID;
+(NSInteger)systemVersion;
+(NativeAppDelegate*)sharedAppDelegate;

@property (retain, nonatomic) UIWindow*     window;             //  应用普通窗口
@property (retain, nonatomic) UIWindow*     alertViewWindow;    //  AlertView 窗口

@property (nonatomic, copy) NSString*       currLanguage;
@property (nonatomic, assign) NetworkStatus currNetStatus;
@property (nonatomic, retain) Reachability* networkreach;

@property (nonatomic, assign) BOOL isLanguageCN;            //  是否使用中文语言
@property (nonatomic, assign) BOOL isLanguageSimpleChinese; //  是否使用简体中文语言

+ (NSString*)appVersion;
+ (NSString*)appShortVersion;

+ (NSString*)deviceInfo;

- (UIViewController*)getAlertViewWindowViewController;

-(MyNavigationController*)newNavigationController:(UIViewController*)vc;
-(MyNavigationController*)newNavigationControllerWithoutRelease:(UIViewController*)vc;

- (void)initLanguageInfo;

-(BOOL)isNetworkViaWifi;
-(BOOL)isNetworkVia2G3G;
-(int)currNetworkStatus;
-(CGFloat)getRequestTimeout;
-(NSString*)getNetworkStatusDesc;

//  switch
- (void)switchTheme;
- (void)switchLanguage;

@end
