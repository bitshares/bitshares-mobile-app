//
//  MySecurityFileMgr.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "MySecurityFileMgr.h"
#import "OrgUtils.h"

@implementation MySecurityFileMgr

+ (id)loadDicSecFile:(NSString*)fullname
{
    //  TODO:fowallet 发布前考虑是否加密
    NSData* data = [NSData dataWithContentsOfFile:fullname];
    if (!data){
        return nil;
    }
    NSError* err = nil;
    id response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers|NSJSONReadingAllowFragments error:&err];
    if (err || !response){
        return nil;
    }
    return response;
}

+ (BOOL)saveSecFile:(id)obj path:(NSString*)fullname
{
    //  TODO:fowallet 发布前考虑是否加密
    NSError* err = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:obj options:NSJSONReadingAllowFragments error:&err];
    if (!data || err){
        return NO;
    }
    return [OrgUtils writeFileAny:data withFullPath:fullname withDirPath:nil];
}

@end
