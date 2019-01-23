//
//  CurveSlider.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <Foundation/Foundation.h>

@class CurveSlider;
@protocol CurveSliderDelegate <NSObject>
@optional
- (void)onValueChanged:(CurveSlider*)curve_slider slider:(UISlider*)slider value:(CGFloat)value;
@end

@interface CurveSlider : NSObject

@property (nonatomic, assign) id<CurveSliderDelegate> delegate;

- (id)initWithSlider:(UISlider*)slider max:(CGFloat)max mapping_min:(CGFloat)mapping_min mapping_max:(CGFloat)mapping_max;

/**
 * 设置最小、最大、当前值
 */
- (void)set_min:(CGFloat)min;
- (void)set_max:(CGFloat)max;
- (void)set_value:(CGFloat)progress;
- (CGFloat)get_value;

@end
