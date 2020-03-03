//
//  VCSlideControllerBase.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBase.h"

@interface VCSlideControllerBase : VCBase<UIGestureRecognizerDelegate>
{
    NSArray*    _subvcArrays;
}

@property (nonatomic, assign) BOOL enableTapSpaceEndInput;  //  点击空白区域关闭键盘（调用endInput方法）

- (VCBase*)currentPage;
- (UIButton*)buttonWithTag:(NSInteger)tag;

/**
 *  (protected) 页面切换事件
 */
- (void)onPageChanged:(NSInteger)tag;

@end
