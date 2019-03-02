//
//  ViewSimulateActionSheet.h
//  ViewSimulateActionSheet
//
//
#import <UIKit/UIKit.h>

@class ViewSimulateActionSheet;
@protocol ViewSimulateActionSheetDelegate <UIPickerViewDelegate>

-(void)actionCancle:(ViewSimulateActionSheet*)sheet;
-(void)actionDone:(ViewSimulateActionSheet*)sheet;

@end

@interface ViewSimulateActionSheet : UIView

@property(assign, nonatomic) id<ViewSimulateActionSheetDelegate> delegate;
@property(retain, nonatomic) UIView* toolBar;
@property(retain, nonatomic) UIPickerView* pickerView;
@property(strong, nonatomic) NSString* custom_tag;

+(instancetype)styleDefault;

-(void)showInView:(UIView *)view;
-(void)dismissWithCompletion:(void (^)())completion;
-(void)selectRow:(NSInteger)row inComponent:(NSInteger)component animated:(BOOL)anime;
-(NSInteger)selectedRowInComponent:(NSInteger)component;

@end
