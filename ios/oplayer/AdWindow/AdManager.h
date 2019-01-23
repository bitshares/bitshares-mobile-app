//
//  AdManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>

@interface AdManager : NSObject

+ (AdManager*)sharedAdManager;

- (NSDictionary*)loadAdInfo;
- (NSDictionary*)loadDefaultAdInfo;
- (void)updateAdInfoFromVersion:(NSDictionary*)version_json;

@end
