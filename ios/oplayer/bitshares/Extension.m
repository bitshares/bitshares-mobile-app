//
//  Extension.m
//
//  Created by SYALON on 13-9-3.
//
//

#import "Extension.h"
#import "OrgUtils.h"

@implementation UIView (Aux)

- (UIView*)findSubview:(Class)klass resursion:(BOOL)resursion
{
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:klass]) {
            return subview;
        }
    }
    
    if (resursion) {
        for (UIView *subview in self.subviews) {
            UIView *tempView = [subview findSubview:klass resursion:resursion];
            if (tempView) {
                return tempView;
            }
        }
    }
    
    return nil;
}

- (BOOL)iterateSubview:(ViewCallback)handler
{
    if (handler(self)) {
        return YES;
    }
    for (UIView* v1 in self.subviews) {
        if ([v1 iterateSubview:handler]) {
            return YES;
        }
    }
    return NO;
}

@end

@implementation UIButton (Aux)

/*
 *  (public) 无动画更新UIButton中的标题文字。REMARK：UIButtonTypeSystem 风格的按钮更新文字默认会闪烁，而 UIButtonTypeCustom 风格按钮又没有点击动画。
 */
- (void)updateTitleWithoutAnimation:(NSString*)title
{
    [UIView performWithoutAnimation:^{
        [self setTitle:title forState:UIControlStateNormal];
        [self layoutIfNeeded];
    }];
}

/*
 *  (public) 重新排列标题文字和图片等布局方式。REMARK：仅同时存在文字和图片时候才需要用到。
 */
- (void)relayoutTitleImageStyle:(EUIButtonImageLayoutStyle)style space:(CGFloat)space
{
    CGFloat imageWith = self.imageView.image.size.width;
    CGFloat imageHeight = self.imageView.image.size.height;
    CGFloat labelWidth = self.titleLabel.intrinsicContentSize.width;
    CGFloat labelHeight = self.titleLabel.intrinsicContentSize.height;
    
    UIEdgeInsets imageEdgeInsets = UIEdgeInsetsZero;
    UIEdgeInsets labelEdgeInsets = UIEdgeInsetsZero;
    
    switch (style)
    {
        case ebils_top:
        {
            imageEdgeInsets = UIEdgeInsetsMake(-labelHeight-space/2.0, 0, 0, -labelWidth);
            labelEdgeInsets = UIEdgeInsetsMake(0, -imageWith, -imageHeight-space/2.0, 0);
        }
            break;
        case ebils_left:
        {
            imageEdgeInsets = UIEdgeInsetsMake(0, -space/2.0, 0, space/2.0);
            labelEdgeInsets = UIEdgeInsetsMake(0, space/2.0, 0, -space/2.0);
        }
            break;
        case ebils_bottom:
        {
            imageEdgeInsets = UIEdgeInsetsMake(0, 0, -labelHeight-space/2.0, -labelWidth);
            labelEdgeInsets = UIEdgeInsetsMake(-imageHeight-space/2.0, -imageWith, 0, 0);
        }
            break;
        case ebils_right:
        {
            imageEdgeInsets = UIEdgeInsetsMake(0, labelWidth+space/2.0, 0, -labelWidth-space/2.0);
            labelEdgeInsets = UIEdgeInsetsMake(0, -imageWith-space/2.0, 0, imageWith+space/2.0);
        }
            break;
        default:
            break;
    }
    
    self.titleEdgeInsets = labelEdgeInsets;
    self.imageEdgeInsets = imageEdgeInsets;
}

@end

@implementation NSNull (JSON)

- (NSUInteger)length { return 0; }

- (NSInteger)integerValue { return 0; };

- (float)floatValue { return 0.0f; };

- (id)objectForKey:(id)key { return nil; }

- (BOOL)boolValue { return NO; }

@end


@implementation NSData (Encoded)

/**
 *  16进制编码
 */
- (NSString*)hex_encode
{
    NSMutableString* output = [NSMutableString string];
    const unsigned char* dataptr = [self bytes];
    for (NSUInteger i = 0; i < [self length]; ++i) {
        [output appendFormat:@"%02x", dataptr[i]];
    }
    return [output copy];
}

@end

//  TODO:fowallet tmp
@implementation NSDate (WQCalendarLogic)

+ (NSCalendar*)gregorianCalendar
{
    static NSCalendar *_gregorianCalendar;
    @synchronized(self)
    {
        if (!_gregorianCalendar)
        {
            _gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        }
    }
    return _gregorianCalendar;
}

@end

@implementation NSString (BtsppExt)

- (unsigned long long)unsignedLongLongValue
{
    return [[[[NSNumberFormatter alloc] init] numberFromString:self] unsignedLongLongValue];
}

- (unsigned long)unsignedLongValue
{
    return [[[[NSNumberFormatter alloc] init] numberFromString:self] unsignedLongValue];
}

- (NSUInteger)unsignedIntegerValue
{
    return [[[[NSNumberFormatter alloc] init] numberFromString:self] unsignedIntegerValue];
}

/**
 *  16进制编码
 */
- (NSString*)hex_encode
{
    NSMutableString* output = [NSMutableString string];
    const unsigned char* dataptr = (const unsigned char*)[self UTF8String];
    for (NSUInteger i = 0; i < [self length]; ++i) {
        [output appendFormat:@"%02x", dataptr[i]];
    }
    return [output copy];
}

/**
 *  URL 编码/解码
 */
- (NSString*)url_encode
{
    return (__bridge NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, nil, nil, kCFStringEncodingUTF8);
}

- (NSString*)url_decode
{
    return (__bridge NSString*)CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, CFSTR(""));
}

@end

/**
 *  仿ruby操作方法扩展
 */
@implementation NSArray (RubyFilter)

- (void)ruby_each_with_index:(RubyFilterEachWithIndexFunction)func
{
    NSInteger idx = 0;
    for (id obj in self) {
        func(obj, idx);
        ++idx;
    }
}

- (NSArray*)ruby_map:(RubyFilterMapFunction)func
{
    if (0 == [self count]){
        return @[];
    }
    
    NSMutableArray* dst = [NSMutableArray array];
    for (id obj in self) {
        [dst addObject:func(obj)];
    }
    
    return [dst copy];
}

- (BOOL)ruby_all:(RubyFilterBoolFunction)func
{
    for (id obj in self) {
        if (!func(obj)){
            return NO;
        }
    }
    return YES;
}

- (BOOL)ruby_any:(RubyFilterBoolFunction)func
{
    for (id obj in self) {
        if (func(obj)){
            return YES;
        }
    }
    return NO;
}

- (id)ruby_find:(RubyFilterBoolFunction)func
{
    for (id obj in self) {
        if (func(obj)){
            return obj;
        }
    }
    return nil;
}

- (NSArray*)ruby_select:(RubyFilterBoolFunction)func
{
    if (0 == [self count]){
        return @[];
    }
    
    NSMutableArray* dst = [NSMutableArray array];
    for (id obj in self) {
        if (func(obj)){
            [dst addObject:obj];
        }
    }
    
    return [dst copy];
}

@end

@implementation NSArray (SafeExt)

- (id)safeObjectAtIndex:(NSUInteger)index
{
    if (index >= [self count]){
        return nil;
    }
    return [self objectAtIndex:index];
}

@end

@implementation NSDictionary (SafeExt)

/*
 *  获取字符串，如果value不是字符串，则返回format后的值。
 */
- (id)optString:(id)aKey
{
    id value = [self objectForKey:aKey];
    if (value && ![value isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"%@", value];
    }
    return value;
}

@end

@implementation NSObject (BtsppExt)

- (id)ruby_apply:(RubyApplyBody)func
{
    func(self);
    return self;
}

/*
 *  (public) 序列化为json字符串。
 */
- (id)to_json:(BOOL)as_data
{
    return [OrgUtils to_json:self as_data:as_data];
}

- (id)to_json
{
    return [self to_json:NO];
}

@end
