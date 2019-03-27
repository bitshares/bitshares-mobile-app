//
//  LangManager.m
//  oplayer
//
//  Created by SYALON on 01/28/19.
//
//

#import "LangManager.h"
#import "AppCacheManager.h"
#import "NativeAppDelegate.h"
#import <objc/runtime.h>

static char* const __bitshares_bundle_key__ = "__bitshares_bundle_key__";
static NSString* const kCurrentLanguageKey = @"kCurrentLanguageKey";

@implementation MultiLanguageBundle

- (NSString*)localizedStringForKey:(NSString*)key value:(NSString*)value table:(NSString*)tableName
{
    NSBundle* bundle = objc_getAssociatedObject(self, __bitshares_bundle_key__);
    if (bundle) {
        return [bundle localizedStringForKey:key value:value table:tableName];
    } else {
        return [super localizedStringForKey:key value:value table:tableName];
    }
}

@end

@implementation NSBundle(Language)

+ (void)setLanguage:(NSString*)language
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        object_setClass([NSBundle mainBundle], [MultiLanguageBundle class]);
    });
    id bundle = language ? [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:language ofType:@"lproj"]] : nil;
    objc_setAssociatedObject([NSBundle mainBundle], __bitshares_bundle_key__, bundle, OBJC_ASSOCIATION_RETAIN);
}

@end

static LangManager *_sharedLangManager = nil;

@interface LangManager()
{
    NSString*   _currLangCode;
}
@end

@implementation LangManager

@synthesize dataArray;
@synthesize currLangCode = _currLangCode;

+ (LangManager*)sharedLangManager
{
    @synchronized(self)
    {
        if(!_sharedLangManager)
        {
            _sharedLangManager = [[LangManager alloc] init];
        }
        return _sharedLangManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        self.currLangCode = nil;
        self.dataArray = @[
                           @{@"langNameKey":@"kLangKeyZhSimple", @"langCode":@"zh-Hans"},
                           @{@"langNameKey":@"kLangKeyEn", @"langCode":@"en"},
                           @{@"langNameKey":@"kLangKeyJa", @"langCode":@"ja"},
                           ];
    }
    return self;
}

- (void)dealloc
{
    self.dataArray = nil;
    self.currLangCode = nil;
}

- (NSString*)getCurrentLanguageName
{
    if (self.currLangCode){
        for (id langInfo in self.dataArray) {
            if ([[langInfo objectForKey:@"langCode"] isEqualToString:self.currLangCode]){
                return NSLocalizedString([langInfo objectForKey:@"langNameKey"], @"");
            }
        }
    }
    return @"";
}

- (void)initCurrentLanguage
{
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    id currentLanguage = [pAppCache getPref:kCurrentLanguageKey];
    if (!currentLanguage) {
        currentLanguage = @"en";            //  default lang is english
        NSArray* languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
        if ([languages count] > 0) {
            if ([languages[0] rangeOfString:@"zh"].location == 0){
                currentLanguage = @"zh-Hans";   //  lproj file
            }else if ([languages[0] rangeOfString:@"ja"].location == 0){
                currentLanguage = @"ja";        //  lproj file
            }
        }
        [[pAppCache setPref:kCurrentLanguageKey value:currentLanguage] saveCacheToFile];
    }
    self.currLangCode = currentLanguage;
    [NSBundle setLanguage:currentLanguage];
}

- (void)saveLanguage:(NSString*)langCode
{
    self.currLangCode = langCode;
    [[[AppCacheManager sharedAppCacheManager] setPref:kCurrentLanguageKey value:langCode] saveCacheToFile];
    [NSBundle setLanguage:langCode];
    [[NativeAppDelegate sharedAppDelegate] switchLanguage];
    
}

@end
