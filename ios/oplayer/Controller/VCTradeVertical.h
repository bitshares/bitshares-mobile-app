//
//  VCTradeVertical.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

@interface VCTradeVerticalSubPage : VCBase
@end

@interface VCTradeVertical : VCSlideControllerBase

@end

@interface VCTradeVerticalBuyOrSell : VCBase

- (id)initWithBuyMode:(BOOL)buy;

@end
