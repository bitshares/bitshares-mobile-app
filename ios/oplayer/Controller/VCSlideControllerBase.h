//
//  VCSlideControllerBase.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBase.h"

@interface VCSlideControllerBase : VCBase
{
    NSArray*    _subvcArrays;
}

- (UIButton*)buttonWithTag:(NSInteger)tag;

@end
