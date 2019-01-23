//
//  ViewRightTextAndCellButton.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewRightTextAndCellButton : UITableViewCellBase

//  REMARK：是否关闭tableview的延迟如果，因为tableview为了响应拖拽等事件，对tableview内部按钮点击事件有延迟，类似预定按钮需要关闭。
@property (nonatomic, assign) BOOL disableDelayTouch;

@end
