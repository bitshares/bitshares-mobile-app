//
//  ViewAutoresizeContailerHor.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//  水平方向自动调整尺寸的容器

#import <UIKit/UIKit.h>

@interface ViewAutoresizeContailerHor : UIView

- (void)addSubview:(UIView*)view tag:(NSInteger)tag;
- (void)resizeFrame;

@property (nonatomic, assign) CGFloat fViewIntervalSpace;   //  子view间隔

@end

@interface TailerViewAssetAndButtons : ViewAutoresizeContailerHor

- (id)initWithHeight:(CGFloat)fHeight asset_name:(NSString*)asset_name;
- (id)initWithHeight:(CGFloat)fHeight asset_name:(NSString*)asset_name button_names:(NSArray*)button_names target:(id)target action:(SEL)action;

- (void)drawAssetName:(NSString*)asset_name;
- (void)drawButtonNames:(NSArray*)button_names;

@property (nonatomic, strong) UILabel* lbAssetName;

@end
