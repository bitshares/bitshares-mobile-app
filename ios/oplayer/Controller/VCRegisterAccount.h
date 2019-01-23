//
//  VCRegisterAccount.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

typedef void (^ImportAccountSuccessCallback)();

@interface VCRegisterAccount : VCSlideControllerBase

- (id)initWithSuccessCallback:(ImportAccountSuccessCallback)callback;

@end
