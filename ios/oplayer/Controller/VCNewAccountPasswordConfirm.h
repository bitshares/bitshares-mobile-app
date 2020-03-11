//
//  VCNewAccountPasswordConfirm.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCNewAccountPasswordConfirm : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithUrlHash:(NSDictionary*)url_hash result_promise:(WsPromiseObject*)result_promise;

@end
