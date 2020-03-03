//
//  ViewCheckBox.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//  checkbox选择框。

#import <UIKit/UIKit.h>

@interface ViewCheckBox : UIView

@property (nonatomic, strong) UIColor* colorForChecked;
@property (nonatomic, strong) UIColor* colorForUnchecked;
@property (nonatomic, assign) BOOL isChecked;
@property (nonatomic, strong) UILabel* labelTitle;

@end
