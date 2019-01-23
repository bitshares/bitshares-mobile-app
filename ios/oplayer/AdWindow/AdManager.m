//
//  AdManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "AdManager.h"
#import "VCAdIntro.h"
#import "OrgUtils.h"
#import "AppCacheManager.h"

static AdManager *_sharedAdManager = nil;

@interface AdManager()
{
}
@end

@implementation AdManager

+(AdManager *)sharedAdManager
{
    @synchronized(self)
    {
        if(!_sharedAdManager)
        {
            _sharedAdManager = [[AdManager alloc] init];
        }
        return _sharedAdManager;
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

/**
 *  加载本次启动显示的广告信息
 */
- (NSDictionary*)loadAdInfo
{
    return (NSDictionary*)[[AppCacheManager sharedAppCacheManager] getPref:@"kAdInfos"];
}

/**
 *  获取默认广告信息
 */
- (NSDictionary*)loadDefaultAdInfo
{
    //  TODO:fowallet 启动时是否添加广告。
    
    //  REMARK：默认内置广告图片、无url，广告4s。
    return [NSDictionary dictionaryWithObjectsAndKeys:@"defaultAd", @"img", @(4), @"sec", @YES, @"_fromBundle", @(kBuildinAd_DefaultTutorial), @"_buildin", nil];
}

/**
 *  更新广告信息（从version.json获取广告数据）
 *  广告条目结构 {img必须 url可选 ts可选}
 */
- (void)updateAdInfoFromVersion:(NSDictionary*)version_json
{
    //  1、服务器取消了广告则清除本地广告数据
    if (!version_json){
        [self clearNativeAdInfo];
        return;
    }
    NSDictionary* adinfo = [version_json objectForKey:@"ad"];
    if (!adinfo){
        [self clearNativeAdInfo];
        return;
    }
    NSString* imgurl = [adinfo objectForKey:@"img"];
    if (!imgurl || [imgurl isEqualToString:@""]){
        [self clearNativeAdInfo];
        return;
    }
    
    //  2、服务器开启广告的情况
    
    NSString* newimg_baseurl = [[imgurl lastPathComponent] lowercaseString];
    NSString* adurl = [adinfo objectForKey:@"url"];
    CGFloat seconds = [[adinfo objectForKey:@"ts"] floatValue];
    
    //  广告没变化则不用下载广告图片，仅更新广告参数。
    AppCacheManager* appCache = [AppCacheManager sharedAppCacheManager];
    id adinfos = [appCache getPref:@"kAdInfos"];
    if (adinfos && [[adinfos objectForKey:@"img"] isEqualToString:newimg_baseurl]){
        [self updateAdInfo:newimg_baseurl url:adurl sec:seconds];
        return;
    }

    //  下载新广告数据
    NSString* fullname = [OrgUtils makeFullPathByAdStorage:newimg_baseurl];
    
    //  下载广告图片
    [OrgUtils asyncFetchUrl:imgurl completionBlock:^(NSData* rawdata) {
        if (!rawdata){
            NSLog(@"download ad image failed...");
        }else{
            if ([OrgUtils writeFileAny:rawdata withFullPath:fullname withDirPath:nil]){
                //  删除旧广告并更新广告参数
                [self clearNativeAdInfo];
                [self updateAdInfo:newimg_baseurl url:adurl sec:seconds];
                NSLog(@"update ad info ok...");
            }else{
                NSLog(@"save ad image failed...");
            }
        }
    }];
}

/**
 *  (PRIVATE) 更新广告参数
 */
- (void)updateAdInfo:(NSString*)img url:(NSString*)url sec:(CGFloat)seconds
{
    //  广告最低3s
    if (seconds <= 3.0f){
        seconds = 3.0f;
    }
    
    NSDictionary* newAdInfo = nil;
    if (url && ![url isEqualToString:@""]){
        newAdInfo = [NSDictionary dictionaryWithObjectsAndKeys:img, @"img", url, @"url", @(seconds), @"sec", nil];
    }else{
        newAdInfo = [NSDictionary dictionaryWithObjectsAndKeys:img, @"img", @(seconds), @"sec", nil];
    }
    
    //  写入缓存
    [[[AppCacheManager sharedAppCacheManager] setPref:@"kAdInfos" value:newAdInfo] saveCacheToFile];
}

/**
 *  (PRIVATE) 服务器删除了广告则删掉本地广告信息
 */
- (void)clearNativeAdInfo
{
    AppCacheManager* appCache = [AppCacheManager sharedAppCacheManager];
    id adinfos = [appCache getPref:@"kAdInfos"];
    if (adinfos){
        //  删除广告图片
        NSString* basename = [adinfos objectForKey:@"img"];
        NSString* fullname = [OrgUtils makeFullPathByAdStorage:basename];
        [OrgUtils deleteFile:fullname];
        //  删除广告信息
        [[appCache deletePref:@"kAdInfos"] saveCacheToFile];
    }
}

@end
