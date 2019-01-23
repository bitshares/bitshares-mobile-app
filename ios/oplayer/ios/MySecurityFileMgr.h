//
//  MySecurityFileMgr.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>

@interface MySecurityFileMgr : NSObject

+ (id)loadDicSecFile:(NSString*)fullname;
+ (BOOL)saveSecFile:(id)obj path:(NSString*)fullname;

@end
