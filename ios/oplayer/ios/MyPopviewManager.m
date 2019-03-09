//
//  MyPopviewManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "MyPopviewManager.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"

#import "objc/runtime.h"

static MyPopviewManager *_sharedMyPopviewManager = nil;
static const char* __picker_view_args_addr__ = "__picker_view_args_addr__";

@interface MyPopviewManager()
{
    NSInteger               _popViewUniqueId;
    NSMutableDictionary*    _popViewIdBlockHash;
    BOOL                    _enableUIAlertController;
    
    
}
@end

@implementation MyPopviewManager

+(MyPopviewManager *)sharedMyPopviewManager
{
    @synchronized(self)
    {
        if(!_sharedMyPopviewManager)
        {
            _sharedMyPopviewManager = [[MyPopviewManager alloc] init];
        }
        return _sharedMyPopviewManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _popViewUniqueId = 0;
        _popViewIdBlockHash = [[NSMutableDictionary alloc] init];
        _enableUIAlertController = [NativeAppDelegate systemVersion] >= 8;
    }
    return self;
}

- (void)dealloc
{
    [_popViewIdBlockHash removeAllObjects];
}

- (void)showActionSheet:(UIViewController*)vc message:(NSString*)message cancel:(NSString*)cancelbuttonname items:(NSArray*)itemnamelist callback:(Arg2CompletionBlock)callback
{
    [self showActionSheet:vc message:message cancel:cancelbuttonname red:nil items:itemnamelist callback:callback];
}

- (void)showActionSheet:(UIViewController*)vc message:(NSString*)message cancel:(NSString*)cancelbuttonname red:(NSString*)redbuttonname items:(NSArray*)itemnamelist callback:(Arg2CompletionBlock)callback
{
    if (_enableUIAlertController)
    {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
        NSInteger cancelIndex = itemnamelist ? [itemnamelist count] : 0;
        //  [红色按钮]
        if (redbuttonname){
            cancelIndex += 1;
            UIAlertAction* action = [UIAlertAction actionWithTitle:redbuttonname style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action)
                                     {
                                         callback(0, cancelIndex);
                                     }];
            [alertController addAction:action];
        }
        
        //  [普通按钮]
        if (itemnamelist){
            NSInteger offset = redbuttonname ? 1 : 0;
            for (NSUInteger idx = 0; idx < [itemnamelist count]; ++idx)
            {
                NSString* itemname = [itemnamelist objectAtIndex:idx];
                UIAlertAction* action = [UIAlertAction actionWithTitle:itemname style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
                                         {
                                             callback(offset + idx, cancelIndex);
                                         }];
                [alertController addAction:action];
            }
        }
        
        //  取消按钮
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelbuttonname style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
                                       {
                                           callback(cancelIndex, cancelIndex);
                                       }];
        [alertController addAction:cancelAction];
        
        //  for ipad
        if (alertController.popoverPresentationController)
        {
            UIView* v = vc.view;
            v.autoresizingMask = UIViewAutoresizingNone;
            v.translatesAutoresizingMaskIntoConstraints = NO;
            [alertController setModalPresentationStyle:UIModalPresentationPopover];
            alertController.popoverPresentationController.permittedArrowDirections = (UIPopoverArrowDirection)0;//UIPopoverArrowDirectionAny;
            alertController.popoverPresentationController.sourceView = v;
            alertController.popoverPresentationController.sourceRect = v.bounds;
            alertController.view.translatesAutoresizingMaskIntoConstraints = NO;
            alertController.view.autoresizingMask = UIViewAutoresizingNone;
        }
        
        [vc presentViewController:alertController animated:YES completion:nil];
    }
    else
    {
        //  [红色按钮]
        UIActionSheet* pSheet = [[UIActionSheet alloc] initWithTitle:message
                                                            delegate:self
                                                   cancelButtonTitle:nil
                                              destructiveButtonTitle:redbuttonname
                                                   otherButtonTitles:nil];
        
        //  [普通按钮]
        if (itemnamelist){
            for (NSString* itemname in itemnamelist)
            {
                [pSheet addButtonWithTitle:itemname];
            }
        }
        
        //  取消按钮
        pSheet.cancelButtonIndex = [pSheet addButtonWithTitle:cancelbuttonname];
        
        //  设置标记
        pSheet.tag = ++_popViewUniqueId;
        [_popViewIdBlockHash setObject:[callback copy] forKey:[NSString stringWithFormat:@"%@", @(_popViewUniqueId)]];
        
        //  显示
        [pSheet showInView:vc.view];
//        [pSheet release];
    }
}

#pragma mark- UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSLog(@"actionSheet buttonIndex = %@ tag = %@", @(buttonIndex), @(actionSheet.tag));
    NSString* key = [NSString stringWithFormat:@"%@", @(actionSheet.tag)];
    Arg2CompletionBlock block = [_popViewIdBlockHash objectForKey:key];
    if (block){
        block(buttonIndex, actionSheet.cancelButtonIndex);
        [_popViewIdBlockHash removeObjectForKey:key];
    }
}

/**
 *  在底部显示列表选择控件
 */
- (WsPromise*)showModernListView:(UIViewController*)vc
                         message:(NSString*)message
                           items:(NSArray*)itemlist
                         itemkey:(NSString*)itemkey
                    defaultIndex:(NSInteger)defaultIndex
{
    assert(itemlist && itemkey);
    assert(defaultIndex < [itemlist count]);
    WsPromise* p = [WsPromise promise:(^(WsResolveHandler resolve, WsRejectHandler reject) {
        ViewSimulateActionSheet* sheet = [ViewSimulateActionSheet styleDefault:message];
        id picker_args = @{
                           @"vc":vc,
                           @"items":itemlist,
                           @"itemkey":itemkey,
                           @"promise":@{@"resolve":resolve, @"reject":reject},
                           };
        sheet.delegate = self;
        sheet.cancelable = YES;
        objc_setAssociatedObject(sheet.pickerView, __picker_view_args_addr__, picker_args, OBJC_ASSOCIATION_RETAIN);
        if (defaultIndex >= 0){
            [sheet selectRow:defaultIndex inComponent:0 animated:NO];
        }
        if ([vc isKindOfClass:[UINavigationController class]]){
            UINavigationController* navi = (UINavigationController*)vc;
            navi.interactivePopGestureRecognizer.enabled = NO;
        }
        [sheet showInView:vc.view];
    })];
    return p;
}

-(void)actionCancle:(ViewSimulateActionSheet*)sheet
{
    [sheet dismissWithCompletion:^{
        id picker_args = objc_getAssociatedObject(sheet.pickerView, __picker_view_args_addr__);
        assert(picker_args && [picker_args isKindOfClass:[NSDictionary class]]);
        id vc = [picker_args objectForKey:@"vc"];
        if ([vc isKindOfClass:[UINavigationController class]]){
            UINavigationController* navi = (UINavigationController*)vc;
            navi.interactivePopGestureRecognizer.enabled = YES;
        }
        WsResolveHandler resolve = [[picker_args objectForKey:@"promise"] objectForKey:@"resolve"];
        resolve(nil);
    }];
}

-(void)actionDone:(ViewSimulateActionSheet*)sheet
{
    [sheet dismissWithCompletion:^{
        id picker_args = objc_getAssociatedObject(sheet.pickerView, __picker_view_args_addr__);
        assert(picker_args && [picker_args isKindOfClass:[NSDictionary class]]);
        id vc = [picker_args objectForKey:@"vc"];
        if ([vc isKindOfClass:[UINavigationController class]]){
            UINavigationController* navi = (UINavigationController*)vc;
            navi.interactivePopGestureRecognizer.enabled = YES;
        }
        WsResolveHandler resolve = [[picker_args objectForKey:@"promise"] objectForKey:@"resolve"];
        resolve([[picker_args objectForKey:@"items"] objectAtIndex:[sheet selectedRowInComponent:0]]);
    }];
}

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    id picker_args = objc_getAssociatedObject(pickerView, __picker_view_args_addr__);
    assert(picker_args && [picker_args isKindOfClass:[NSDictionary class]]);
    return [[picker_args objectForKey:@"items"] count];
}

//- (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component __TVOS_PROHIBITED
//{
//    return [_pickerDataArray objectAtIndex:row];
//}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(nullable UIView *)view __TVOS_PROHIBITED
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    for (UIView* subView in pickerView.subviews) {
        if (subView.frame.size.height <= 1.0f){
            subView.backgroundColor = theme.bottomLineColor;
        }
    }
    
    id picker_args = objc_getAssociatedObject(pickerView, __picker_view_args_addr__);
    assert(picker_args && [picker_args isKindOfClass:[NSDictionary class]]);
    
    UILabel* label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [[[picker_args objectForKey:@"items"] objectAtIndex:row] objectForKey:picker_args[@"itemkey"]];
    label.textColor = theme.textColorMain;
    
    return label;
}

@end
