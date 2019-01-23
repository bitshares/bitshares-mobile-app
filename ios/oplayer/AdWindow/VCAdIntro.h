//
//  VCAdIntro.h
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCBase.h"

enum kBuildinAdID
{
    kBuildinAd_Invalid = 0,         //  无效编号
    kBuildinAd_DefaultTutorial,       //  [内置] 广告
    
    kBuildinAd_Max
};

@interface VCAdIntro : VCBase

@end
