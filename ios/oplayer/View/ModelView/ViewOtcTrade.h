//
//  ViewOtcTrade.h
//  ViewOtcTrade
//
//  OTC下单时模态输入框

#import "ViewFullScreenBase.h"

@interface ViewOtcTrade : ViewFullScreenBase<UITextFieldDelegate>

- (instancetype)initWithAdInfo:(id)ad_info;

@end
