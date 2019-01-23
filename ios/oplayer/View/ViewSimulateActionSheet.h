//
//  ViewSimulateActionSheet.h
//  ViewSimulateActionSheet
//
//  Created by 张 聪 on 15/1/14.
//  Copyright (c) 2015年 张 聪. All rights reserved.
//
#import <UIKit/UIKit.h>

@protocol ViewSimulateActionSheetDelegate <UIPickerViewDelegate>
//  点击取消的回调接口
-(void)actionCancle;
//  点击确定的回调接口
-(void)actionDone;
@end

@interface ViewSimulateActionSheet : UIView

@property(assign, nonatomic) id<ViewSimulateActionSheetDelegate> delegate;
@property(retain, nonatomic) UIView* toolBar;
@property(retain, nonatomic) UIPickerView* pickerView;

+(instancetype)styleDefault;
-(void)showInView:(UIView *)view;
-(void)dismiss:(UIView *)view completion:(void (^)())completion;
//  选中指定的行列
-(void)selectRow:(NSInteger)row inComponent:(NSInteger)component animated:(BOOL)anime;
//  获取被选中的行列
-(NSInteger)selectedRowInComponent:(NSInteger)component;
@end
