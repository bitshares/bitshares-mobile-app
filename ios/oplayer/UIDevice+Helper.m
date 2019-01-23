//
//  UIDevice+Resolutions.m
//  Test_common
//
//  Created by wangzhipeng on 13-1-30.
//  Copyright (c) 2013年 com.comsoft. All rights reserved.
//

#import "UIDevice+Helper.h"

@implementation UIDevice (Resolutions)

/******************************************************************************
 函数名称 : + (UIDeviceResolution) currentResolution
 函数描述 : 获取当前分辨率
 
 输入参数 : N/A
 输出参数 : N/A
 返回参数 : N/A
 备注信息 :
 ******************************************************************************/
+ (UIDeviceResolution) currentResolution {
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        if ([[UIScreen mainScreen] respondsToSelector: @selector(scale)]) {
            CGSize result = [[UIScreen mainScreen] bounds].size;
            result = CGSizeMake(result.width * [UIScreen mainScreen].scale, result.height * [UIScreen mainScreen].scale);
            if (result.height <= 480.0f)
                return UIDevice_iPhoneStandardRes;
            return (result.height > 960 ? UIDevice_iPhoneTallerHiRes : UIDevice_iPhoneHiRes);
        } else
            return UIDevice_iPhoneStandardRes;
    } else
        return (([[UIScreen mainScreen] respondsToSelector: @selector(scale)]) ? UIDevice_iPadHiRes : UIDevice_iPadStandardRes);
}

/******************************************************************************
 函数名称 : + (UIDeviceResolution) currentResolution
 函数描述 : 当前是否运行在iPhone5端
 输入参数 : N/A
 输出参数 : N/A
 返回参数 : N/A
 备注信息 :
 ******************************************************************************/
+ (BOOL)isRunningOniPhone5{
    if ([self currentResolution] == UIDevice_iPhoneTallerHiRes) {
        return YES;
    }
    return NO;
}

/******************************************************************************
 函数名称 : + (BOOL)isRunningHighResolution
 函数描述 : 判断是否运行在高清设备上
 输入参数 : N/A
 输出参数 : N/A
 返回参数 : N/A
 备注信息 :
 ******************************************************************************/
+ (BOOL)isRunningHighResolution
{
    UIDeviceResolution res = [self currentResolution];
    if (res == UIDevice_iPhoneHiRes || res == UIDevice_iPhoneTallerHiRes || res == UIDevice_iPadHiRes)
        return YES;
    return NO;
}

/******************************************************************************
 函数名称 : + (BOOL)isRunningOniPhone
 函数描述 : 当前是否运行在iPhone端
 输入参数 : N/A
 输出参数 : N/A
 返回参数 : N/A
 备注信息 :
 ******************************************************************************/
+ (BOOL)isRunningOniPhone{
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
}

/******************************************************************************
 函数名称 : + (BOOL)isRunningOniPad
 函数描述 : 当前是否运行在iPad端
 输入参数 : N/A
 输出参数 : N/A
 返回参数 : N/A
 备注信息 :
 ******************************************************************************/
+ (BOOL)isRunningOniPad
{
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
}

@end