//
//  MyTextField.h
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import <UIKit/UIKit.h>

@interface MyTextField : UITextField

@property (nonatomic, strong) UIColor* colorClearButtonHighlighted;
@property (nonatomic, strong) UIColor* colorClearButtonNormal;

@property (nonatomic, assign) BOOL showRectBorder;
@property (nonatomic, assign) BOOL showBottomLine;
@property (nonatomic, assign) BOOL updateClearButtonTintColor;

- (void)setLeftTitleView:(NSString*)title frame:(CGRect)frame;
- (void)setLeftTitleView:(NSString*)title;

@end
