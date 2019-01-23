//
//  CurveSlider.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "CurveSlider.h"
#import "ChainObjectManager.h"

@interface CurveSlider()
{
    __weak UISlider*    _slider;
    
    CGFloat             _mapping_min;
    CGFloat             _mapping_max;
    CGFloat             _mapping_diff;
    CGFloat             _max_y_value;
}

@end

@implementation CurveSlider

@synthesize delegate;

- (void)dealloc
{
    self.delegate = nil;
    _slider = nil;
}

- (id)initWithSlider:(UISlider*)slider max:(CGFloat)max mapping_min:(CGFloat)mapping_min mapping_max:(CGFloat)mapping_max
{
    self = [super init];
    if (self)
    {
        assert(slider);
        _slider = slider;
        _mapping_min = mapping_min;
        _mapping_max = mapping_max;
        _mapping_diff = mapping_max - mapping_min;
        assert(_mapping_diff >= 0.01f);
        _slider.minimumValue = 0.0f;
        _slider.maximumValue = max;
        _max_y_value = [self _formula_01:max];
        //  绑定事件
        [_slider addTarget:self action:@selector(onSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return self;
}

/**
 * 事件：slider值变化。
 */
- (void)onSliderValueChanged:(UISlider*)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onValueChanged:slider:value:)])
    {
        [self.delegate onValueChanged:self slider:sender value:[self x_to_real_value:sender.value]];
    }
}

/**
 * 设置最小、最大、当前值
 */
- (void)set_min:(CGFloat)min
{
    _mapping_min = min;
    _mapping_diff = _mapping_max - _mapping_min;
    assert(_mapping_diff >= 0.01f);
}

- (void)set_max:(CGFloat)max
{
    _mapping_max = max;
    _mapping_diff = _mapping_max - _mapping_min;
    assert(_mapping_diff >= 0.01f);
}

- (void)set_value:(CGFloat)progress
{
    _slider.value = [self real_value_to_x:progress];
}

- (CGFloat)get_value
{
    return [self x_to_real_value:_slider.value];
}

/**
 * 公式01：目前映射公式：y = 0.011 * x^2
 * x范围：0 - _slider_max
 * y范围：0 - 0.011 * _slider_max^2
 * 实际值：y_value / max_y_value * (mapping_max - mapping_min) + mapping_min
 */
- (CGFloat)_formula_01:(CGFloat)x
{
    return 0.011f * x * x;
}

/**
 * 公式01：逆向，通过 y 计算 x。
 */
- (CGFloat)_formula_01_reverse:(CGFloat)y
{
    return roundf(sqrtf(y / 0.011f));
}

/**
 * 映射：slider值（x）到最终实际值
 */
- (CGFloat)x_to_real_value:(CGFloat)x
{
    CGFloat value = _mapping_diff * [self _formula_01:x] / _max_y_value + _mapping_min;
    return fmaxf(fminf(value, _mapping_max), _mapping_min);
}

/**
 * 映射：最终实际值 到 slider值（x）
 */
- (int)real_value_to_x:(CGFloat)value
{
    CGFloat new_value = fmaxf(fminf(value, _mapping_max), _mapping_min);
    CGFloat y_value = (_max_y_value * (new_value - _mapping_min)) / _mapping_diff;
    CGFloat x_value = [self _formula_01_reverse:y_value];
    return fmaxf(0, fminf(x_value, _slider.maximumValue));
}

@end
