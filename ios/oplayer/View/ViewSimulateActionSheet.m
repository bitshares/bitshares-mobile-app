//
//  ViewSimulateActionSheet.m
//  ViewSimulateActionSheet
//

#import "ViewSimulateActionSheet.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"

@interface ViewSimulateActionSheet()
{
    UITapGestureRecognizer* _pTap;
}

@end

@implementation ViewSimulateActionSheet

@synthesize cancelable;

+(instancetype)styleDefault:(NSString*)title
{
    ViewSimulateActionSheet* sheet = [[ViewSimulateActionSheet alloc] initWithFrame:UIScreen.mainScreen.bounds];
    sheet.backgroundColor = [UIColor clearColor];
    sheet.cancelable = NO;
    
    sheet.toolBar = [sheet actionToolBar:title];
    sheet.pickerView = [sheet actionPicker];
    [sheet addSubview:sheet.toolBar];
    [sheet addSubview:sheet.pickerView];
    
    return sheet;
}

- (void)dealloc
{
    _pTap = nil;
}

-(void)_onTap:(UITapGestureRecognizer*)pTap
{
    [self actionCancle];
}

-(void)setupInitPostion:(UIView *)view
{
    [view addSubview:self];
    
    CGFloat pickerViewYpositionHidden = UIScreen.mainScreen.bounds.size.height;
    
    [self.pickerView setFrame:CGRectMake(self.pickerView.frame.origin.x,
                                         pickerViewYpositionHidden,
                                         self.pickerView.frame.size.width,
                                         self.pickerView.frame.size.height)];
    self.pickerView.tintColor = [ThemeManager sharedThemeManager].tintColor;
    
    [self.toolBar setFrame:CGRectMake(self.toolBar.frame.origin.x,
                                      pickerViewYpositionHidden,
                                      self.toolBar.frame.size.width,
                                      self.toolBar.frame.size.height)];
}

-(void)showInView:(UIView *)view
{
    [self setupInitPostion:view];
    
    CGFloat toolBarYposition = UIScreen.mainScreen.bounds.size.height - (self.pickerView.frame.size.height + self.toolBar.frame.size.height);
    
    if (self.cancelable && !_pTap){
        UIView* pTapView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, toolBarYposition)];
        pTapView.backgroundColor = [UIColor clearColor];
        [self addSubview:pTapView];
        _pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_onTap:)];
        _pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
        _pTap.enabled = NO;
        [pTapView addGestureRecognizer:_pTap];
    }

    [UIView animateWithDuration:0.25f
                     animations:^{
                         [self setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.5]];
                         [self.toolBar setFrame:CGRectMake(self.toolBar.frame.origin.x,
                                                           toolBarYposition,
                                                           self.toolBar.frame.size.width,
                                                           self.toolBar.frame.size.height)];
                         
                         [self.pickerView setFrame:CGRectMake(self.pickerView.frame.origin.x,
                                                              toolBarYposition+self.toolBar.frame.size.height,
                                                              self.pickerView.frame.size.width,
                                                              self.pickerView.frame.size.height)];
                     }
                     completion:^(BOOL finished) {
                         if (_pTap){
                             _pTap.enabled = YES;
                         }
                     }];

}

-(void)dismissWithCompletion:(void (^)())completion
{
    if (_pTap){
        _pTap.enabled = NO;
    }
    [UIView animateWithDuration:0.25f
                     animations:^{
                         [self setBackgroundColor:[UIColor clearColor]];
                         [self.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                             UIView* v = (UIView*)obj;
                             [v setFrame:CGRectMake(v.frame.origin.x,
                                                    UIScreen.mainScreen.bounds.size.height,
                                                    v.frame.size.width,
                                                    v.frame.size.height)];
                         }];
                     }
                     completion:^(BOOL finished) {
                         [self removeFromSuperview];
                         completion();
                     }];
}

-(UIView *)actionToolBar:(NSString*)title
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    UIView* tools = [[UIView alloc]initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 44)];
    tools.backgroundColor = theme.tabBarColor;
    UIButton* cancle = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancle setTitle:NSLocalizedString(@"kBtnPickerViewCancel", @"取消") forState:UIControlStateNormal];
    [cancle setTitleColor:theme.textColorMain forState:UIControlStateNormal];
    [cancle addTarget:self action:@selector(actionCancle) forControlEvents:UIControlEventTouchUpInside];
    [cancle sizeToFit];
    [tools addSubview:cancle];
    
    cancle.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *cancleConstraintLeft = [NSLayoutConstraint constraintWithItem:cancle attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:tools attribute:NSLayoutAttributeLeading multiplier:1.0f constant:10.0f];
    NSLayoutConstraint *cancleConstrainY = [NSLayoutConstraint constraintWithItem:cancle attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:tools attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:0];
    [tools addConstraint:cancleConstraintLeft];
    [tools addConstraint:cancleConstrainY];
    
    UIButton* ok = [UIButton buttonWithType:UIButtonTypeSystem];
    [ok setTitle:NSLocalizedString(@"kBtnPickerViewDone", @"确定") forState:UIControlStateNormal];
    [ok setTitleColor:theme.textColorMain forState:UIControlStateNormal];
    [ok addTarget:self action:@selector(actionDone) forControlEvents:UIControlEventTouchUpInside];
    [ok sizeToFit];
    [tools addSubview:ok];
    
    ok.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *okConstraintRight = [NSLayoutConstraint constraintWithItem:ok attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:tools attribute:NSLayoutAttributeTrailing multiplier:1.0f constant:-10.0f];
    NSLayoutConstraint *okConstraintY = [NSLayoutConstraint constraintWithItem:ok attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:tools attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:0];
    [tools addConstraint:okConstraintRight];
    [tools addConstraint:okConstraintY];

    if (title && ![title isEqualToString:@""]){
        UILabel* lb_title = [[UILabel alloc] initWithFrame:tools.bounds];
        lb_title.lineBreakMode = NSLineBreakByWordWrapping;
        lb_title.numberOfLines = 1;
        lb_title.backgroundColor = [UIColor clearColor];
        lb_title.textColor = theme.textColorMain;
        lb_title.textAlignment = NSTextAlignmentCenter;
        lb_title.font = [UIFont systemFontOfSize:16.0f];
        lb_title.text = title;
        [tools addSubview:lb_title];
    }
    
    return tools;
}

-(UIPickerView *)actionPicker
{
    UIPickerView* picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 44, UIScreen.mainScreen.bounds.size.width, 216)];
    picker.showsSelectionIndicator = YES;
    [picker setBackgroundColor:[ThemeManager sharedThemeManager].appBackColor];
    return picker;
}

-(void)selectRow:(NSInteger)row inComponent:(NSInteger)component animated:(BOOL)anime
{
    [_pickerView selectRow:row inComponent:component animated:anime];
}

-(NSInteger)selectedRowInComponent:(NSInteger)component
{
    return [_pickerView selectedRowInComponent:component];
}

-(void)actionDone
{
    if([_delegate respondsToSelector:@selector(actionDone:)]){
        [_delegate actionDone:self];
    }
}

-(void)actionCancle
{
    if ([_delegate respondsToSelector:@selector(actionCancle:)]) {
        [_delegate actionCancle:self];
    }
}

-(void)setDelegate:(id<ViewSimulateActionSheetDelegate>)delegate
{
    _delegate = delegate;
    _pickerView.delegate = delegate;
}
@end
