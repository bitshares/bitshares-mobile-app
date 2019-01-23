//
//  VCDebt.h
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//  抵押借款（无息借贷）

#import "VCBase.h"
#import "CurveSlider.h"

@interface VCDebt : VCBase<UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate, UIScrollViewDelegate, CurveSliderDelegate>

- (void)onTabBarControllerSwitched;

@end
