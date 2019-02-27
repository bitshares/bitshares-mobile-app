//
//  VCKlineIndexSetting.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"
#import "ViewSimulateActionSheet.h"

@interface VCKlineIndexSetting : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, ViewSimulateActionSheetDelegate>

- (id)initWithResultPromise:(WsPromiseObject*)result_promise;

@end
