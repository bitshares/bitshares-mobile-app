//
//  ThemeManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "ThemeManager.h"
#import "SettingManager.h"
#import "NativeAppDelegate.h"

static ThemeManager *_sharedThemeManager = nil;

@interface ThemeManager()
{
    NSArray*                _colorNameList;
    NSMutableArray*         _themeDataArray;    //  主题基本信息列表：{:themeCode=>'dark', :themeName=>'商务黑', :colors=>{colorname=>hexstr, ...}} 的数组
    NSMutableDictionary*    _themeColors;       //  主题对应的颜色对象   key: themeCode  value: {colorname=>UIColor, ...}
}

@property (nonatomic, copy) NSString* currThemeCode;

@end

@implementation ThemeManager

@synthesize appBackColor, contentBackColor, bottomLineColor;
@synthesize buyColor, sellColor, zeroColor, callOrderColor;
@synthesize textColorPercent, textColorHighlight, textColorGray, textColorNormal, textColorMain;
@synthesize ma5Color, ma10Color, ma30Color;
@synthesize navigationBarBackColor, navigationBarTextColor;
@synthesize tabBarColor;
@synthesize mainButtonBackColor, mainButtonTextColor;
@synthesize blockButtonBackColor, blockButtonTextColor;
@synthesize frameButtonBorderColor, frameButtonTextColor;
@synthesize tintColor;
@synthesize iconColor;
@synthesize textColor01, textColor02;
@synthesize noticeColor;
@synthesize ticketColor;

+(ThemeManager *)sharedThemeManager
{
    @synchronized(self)
    {
        if(!_sharedThemeManager)
        {
            _sharedThemeManager = [[ThemeManager alloc] init];
        }
        return _sharedThemeManager;
    }
}

- (void)dealloc
{
    self.currThemeCode = nil;
    if (_themeColors){
        [_themeColors removeAllObjects];
        _themeColors = nil;
    }
    if (_themeDataArray){
        [_themeDataArray removeAllObjects];
        _themeDataArray = nil;
    }
    [self clearColors];
}

- (id)init
{
    self = [super init];
    if (self)
    {
        self.currThemeCode = nil;
        [self clearColors];
        _colorNameList = [[NSArray alloc] initWithObjects:
                          @"appBackColor",
                          @"contentBackColor",
                          @"bottomLineColor",
                          @"buyColor",
                          @"sellColor",
                          @"zeroColor",
                          @"callOrderColor",
                          @"textColorPercent",
                          @"textColorHighlight",
                          @"textColorGray",
                          @"textColorNormal",
                          @"textColorMain",
                          @"ma5Color",
                          @"ma10Color",
                          @"ma30Color",
                          @"navigationBarBackColor",
                          @"navigationBarTextColor",
                          @"tabBarColor",
                          @"mainButtonBackColor",
                          @"mainButtonTextColor",
                          @"blockButtonBackColor",
                          @"blockButtonTextColor",
                          @"frameButtonBorderColor",
                          @"frameButtonTextColor",
                          @"tintColor",
                          @"iconColor",
                          @"textColor01",
                          @"textColor02",
                          @"noticeColor",
                          @"ticketColor",
                          nil];
        
        _themeDataArray = [[NSMutableArray alloc] init];
        _themeColors = [[NSMutableDictionary alloc] init];
        //  REMARK：以下部分在app启动完成之前进行初始化
        //  获取当前默认主题
        id themeInfo = [[SettingManager sharedSettingManager] getThemeInfo];
        //  初始化当前主题颜色
        NSString* themeCode = [themeInfo objectForKey:@"themeCode"];
        [_themeColors setObject:[self genThemeColors:themeInfo] forKey:themeCode];
        //  加载当前主题颜色
        [self loadTheme:themeCode];
    }
    return self;
}

- (void)clearColors
{
    self.appBackColor = nil;
    self.contentBackColor = nil;
    self.bottomLineColor = nil;
    self.buyColor = nil;
    self.sellColor = nil;
    self.zeroColor = nil;
    self.callOrderColor = nil;
    self.textColorPercent = nil;
    self.textColorHighlight = nil;
    self.textColorGray = nil;
    self.textColorNormal = nil;
    self.textColorMain = nil;
    self.ma5Color = nil;
    self.ma10Color = nil;
    self.ma30Color = nil;
    self.navigationBarBackColor = nil;
    self.navigationBarTextColor = nil;
    self.tabBarColor = nil;
    self.mainButtonBackColor = nil;
    self.mainButtonTextColor = nil;
    self.blockButtonBackColor = nil;
    self.blockButtonTextColor = nil;
    self.frameButtonBorderColor = nil;
    self.frameButtonTextColor = nil;
    self.tintColor = nil;
    self.iconColor = nil;
    self.textColor01 = nil;
    self.textColor02 = nil;
    self.noticeColor = nil;
    self.ticketColor = nil;
}

- (UIColor*)genColor:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue
{
    return [UIColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:1.0];
}

+ (UIColor*)genColor:(NSString*)hexstr
{
    NSString* cString = [[hexstr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    //  String should be 6 or 8 characters
    if ([cString length] < 6) return [UIColor whiteColor];
    
    //  strip 0X if it appears
    if ([cString hasPrefix:@"0X"]) cString = [cString substringFromIndex:2];
    
    if ([cString length] != 6) return  [UIColor whiteColor];
    
    //  Separate into r, g, b substrings
    NSRange range;
    range.location = 0;
    range.length = 2;
    NSString* rString = [cString substringWithRange:range];
    
    range.location = 2;
    NSString* gString = [cString substringWithRange:range];
    
    range.location = 4;
    NSString* bString = [cString substringWithRange:range];
    
    //  Scan values
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];
    
    return [UIColor colorWithRed:((float)r / 255.0f) green:((float)g / 255.0f) blue:((float)b / 255.0f) alpha:1.0f];
}

- (NSDictionary*)genThemeColors:(NSDictionary*)themeInfo
{
    if ([[themeInfo objectForKey:@"defaultTheme"] boolValue]){
        return [self genDefaultThemeColors];
    }else{
        id configColors = [themeInfo objectForKey:@"colors"];
        //  REMARK：新增了颜色种类那么缓存的颜色数量就不一致了。
        if ([configColors count] != [_colorNameList count]){
            return [self genDefaultThemeColors];
        }
        NSMutableDictionary* colors = [NSMutableDictionary dictionary];
        for (NSString* colorName in _colorNameList) {
            UIColor *color = [ThemeManager genColor:[configColors objectForKey:colorName]];
            [colors setObject:color forKey:colorName];
        }
        return [colors copy];
    }
}

- (NSArray*)getThemeDataArray
{
    return _themeDataArray;
}

- (NSString*)getThemeNameFromThemeCode:(NSString*)themeCode
{
    for (id themeInfo in _themeDataArray) {
        if ([themeCode isEqualToString:[themeInfo objectForKey:@"themeCode"]]){
            id langKey = [themeInfo objectForKey:@"themeNameLangKey"];
            if (langKey){
                return NSLocalizedString(langKey, @"主题名字");
            }else{
                return [themeInfo objectForKey:@"themeName"];
            }
        }
    }
    if ([themeCode isEqualToString:kAppDefaultThemeCode]){
        return kAppDefaultThemeName;
    }
    return nil;
}

+ (NSDictionary*)getDefaultThemeInfos
{
    //  REMARK：defaultTheme - 是否是本地默认风格
    return [NSDictionary dictionaryWithObjectsAndKeys:kAppDefaultThemeCode, @"themeCode",
            kAppDefaultThemeName, @"themeName",
            @"1", @"defaultTheme",
            @"1", @"themeStatusBarWhite",
            nil];
}

- (void)loadTheme:(NSString*)goalThemeCode
{
    [self switchTheme:goalThemeCode reload:NO];
}

- (void)switchTheme:(NSString*)goalThemeCode reload:(BOOL)reload
{
    if (!self.currThemeCode || ![goalThemeCode isEqualToString:self.currThemeCode]){
        self.currThemeCode = [goalThemeCode copy];
        [self reinitThemeColors:[_themeColors objectForKey:self.currThemeCode]];
        //  切换theme
        if (reload){
            [[NativeAppDelegate sharedAppDelegate] switchTheme];
        }
    }
}

- (void)initThemeFromConfig:(NSArray*)themeList
{
    if (!themeList){
        return;
    }
    
    [_themeDataArray removeAllObjects];
    
    NSDictionary* jsUserCurrentUseTheme = nil;
    BOOL jsExistDefaultTheme = NO;
    if (themeList && [themeList count] > 0){
        for (id themeInfo in themeList) {
            NSString* themeCode = [themeInfo objectForKey:@"themeCode"];
            if ([themeCode isEqualToString:kAppDefaultThemeCode]){
                jsExistDefaultTheme = YES;
            }
            if ([themeCode isEqualToString:self.currThemeCode]){
                jsUserCurrentUseTheme = themeInfo;
            }
            [_themeDataArray addObject:themeInfo];
        }
    }
    
    //  没覆盖默认风格的情况下，把默认风格添加到第一个位置。
    if (!jsExistDefaultTheme){
        [_themeDataArray insertObject:[[self class] getDefaultThemeInfos] atIndex:0];
    }
    
    [_themeColors removeAllObjects];
    for (id themeInfo in _themeDataArray) {
        NSString* themeCode = [themeInfo objectForKey:@"themeCode"];
        [_themeColors setObject:[self genThemeColors:themeInfo] forKey:themeCode];
    }
    
    //  如果用户当前使用的风格，在js里配置发生改变的话，那写入文件，下次启动刷新。
    if (jsUserCurrentUseTheme){
        [[SettingManager sharedSettingManager] setUseConfig:kSettingKey_ThemeInfo obj:jsUserCurrentUseTheme];
    }
}

- (NSDictionary*)genDefaultThemeColors
{
    NSDictionary *defaultTheme = @{
                                   @"themeCode": @"dark",
                                   @"themeName": @"商务黑",
                                   @"colors":
                                       @{
//                                           @"appBackColor"            : @"1c1d1f",//  高端黑
//                                           @"appBackColor"            : @"131e32",  //  暗黑蓝
                                           @"appBackColor"            : @"131f30",  //  暗黑蓝
                                           @"contentBackColor"        : @"333333",
                                           @"bottomLineColor"         : @"1a273a",  //  TODO:fowallet color 颜色是否太深了
//                                           @"bottomLineColor"         : @"ffffff",  //  test color
                                           @"buyColor"                : @"03c087",
                                           @"sellColor"               : @"e76d42",
                                           @"zeroColor"               : @"8c9fad",
                                           @"callOrderColor"          : @"ffff00",
                                           @"textColorPercent"        : @"ffffff",
                                           @"textColorHighlight"      : @"5786d2",
                                           @"textColorGray"           : @"3d526b",
                                           @"textColorNormal"         : @"6d87a8",
                                           @"textColorMain"           : @"ffffff",
                                           @"ma5Color"                : @"f6dc93",
                                           @"ma10Color"               : @"61d1c0",
                                           @"ma30Color"               : @"cb92fe",
                                           
                                           @"navigationBarBackColor"  : @"131f30",  //  同 appBackColor
                                           @"navigationBarTextColor"  : @"ffffff",  //  同 textColorMain
//                                           @"tabBarColor"             : @"fe6c5a",
                                           @"tabBarColor"             : @"172941",  //  火币蓝
                                           @"blockButtonBackColor"    : @"607D8B",
                                           @"blockButtonTextColor"    : @"ffffff",
                                           @"mainButtonBackColor"     : @"e76d42",
                                           @"mainButtonTextColor"     : @"ffffff",
                                           @"frameButtonBorderColor"  : @"607D8B",
                                           @"frameButtonTextColor"    : @"607D8B",
//                                           @"tintColor"               : @"fe6c5a",
                                           @"tintColor"               : @"e76d42",  //  同 textColorHighlight
                                           @"iconColor"               : @"fe6c5a",
                                           @"textColor01"             : @"212121",
                                           @"textColor02"             : @"727272",
                                           @"noticeColor"             : @"fe6c5a",
                                           @"ticketColor"             : @"8d9caa",
                                           }
                                   };
    return [self genThemeColors:defaultTheme];
}

- (void)reinitThemeColors:(NSDictionary*)themeColors
{
    self.appBackColor           = [themeColors objectForKey:@"appBackColor"];
    self.contentBackColor       = [themeColors objectForKey:@"contentBackColor"];
    self.bottomLineColor        = [themeColors objectForKey:@"bottomLineColor"];
    self.buyColor               = [themeColors objectForKey:@"buyColor"];
    self.sellColor              = [themeColors objectForKey:@"sellColor"];
    self.zeroColor              = [themeColors objectForKey:@"zeroColor"];
    self.callOrderColor         = [themeColors objectForKey:@"callOrderColor"];
    self.textColorPercent       = [themeColors objectForKey:@"textColorPercent"];
    self.textColorHighlight     = [themeColors objectForKey:@"textColorHighlight"];
    self.textColorGray          = [themeColors objectForKey:@"textColorGray"];
    self.textColorNormal        = [themeColors objectForKey:@"textColorNormal"];
    self.textColorMain          = [themeColors objectForKey:@"textColorMain"];
    self.ma5Color               = [themeColors objectForKey:@"ma5Color"];
    self.ma10Color              = [themeColors objectForKey:@"ma10Color"];
    self.ma30Color              = [themeColors objectForKey:@"ma30Color"];
    self.navigationBarBackColor = [themeColors objectForKey:@"navigationBarBackColor"];
    self.navigationBarTextColor = [themeColors objectForKey:@"navigationBarTextColor"];
    self.tabBarColor            = [themeColors objectForKey:@"tabBarColor"];
    self.mainButtonBackColor    = [themeColors objectForKey:@"mainButtonBackColor"];
    self.mainButtonTextColor    = [themeColors objectForKey:@"mainButtonTextColor"];
    self.blockButtonBackColor   = [themeColors objectForKey:@"blockButtonBackColor"];
    self.blockButtonTextColor   = [themeColors objectForKey:@"blockButtonTextColor"];
    self.frameButtonBorderColor = [themeColors objectForKey:@"frameButtonBorderColor"];
    self.frameButtonTextColor   = [themeColors objectForKey:@"frameButtonTextColor"];
    self.tintColor              = [themeColors objectForKey:@"tintColor"];
    self.iconColor              = [themeColors objectForKey:@"iconColor"];
    self.textColor01            = [themeColors objectForKey:@"textColor01"];
    self.textColor02            = [themeColors objectForKey:@"textColor02"];
    self.noticeColor            = [themeColors objectForKey:@"noticeColor"];
    self.ticketColor            = [themeColors objectForKey:@"ticketColor"];
}

@end
