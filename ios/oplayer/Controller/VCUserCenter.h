//
//  VCUserCenter.h
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCSlideControllerBase.h"

@interface VCUserCenterPages : VCSlideControllerBase
@end

@interface VCUserCenter : VCBase<UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate>

- (id)initWithOwner:(VCBase*)owner;

@end
