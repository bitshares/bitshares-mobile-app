//
//  SphereMenu.h
//  SphereMenu
//
//  Created by Tu You on 14-8-24.
//  Copyright (c) 2014年 TU YOU. All rights reserved.
//

// 版权属于原作者
// http://code4app.com (cn) http://code4app.net (en)
// 发布代码于最专业的源码分享网站: Code4App.com

#import <UIKit/UIKit.h>

@protocol SphereMenuDelegate <NSObject>

- (void)sphereDidSelected:(int)index;

@end

@interface SphereMenu : UIView

@property (weak, nonatomic) id<SphereMenuDelegate> delegate;

- (void)startAnimation;
- (void)stopAnimation;

- (void)bringToTop;
- (void)setVisible:(BOOL)visible;

- (instancetype)initWithStartPoint:(CGPoint)startPoint
                        startImagePrefix:(NSString *)startImagePrefix
                        startImageNumber:(NSInteger)startImageNumber
                        submenuImages:(NSArray *)images;

@end
