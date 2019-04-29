//
//  VCHtlcList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  HTLC object list / 哈希时间锁合约列表

#import "VCBase.h"
#import "ViewActionsCell.h"

@interface VCHtlcList : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, ViewActionsCellClickedDelegate>

- (id)initWithOwner:(VCBase*)owner fullAccountInfo:(NSDictionary*)accountInfo;

/**
 *  (public) query user htlc objects
 */
- (void)queryUserHTLCs;

@end
