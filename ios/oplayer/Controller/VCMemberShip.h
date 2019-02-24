//
//  VCMemberShip.h
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCBase.h"

@interface VCMemberShip : VCBase<UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate>

- (id)initWithOwner:(VCBase*)owner;

@end
