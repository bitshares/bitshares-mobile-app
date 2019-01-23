//
//  VCProposalAuthorizeEdit.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  授权/否决界面

#import <UIKit/UIKit.h>
#import "VCBase.h"

typedef void (^BtsppApproveCallback)(BOOL isOk, NSDictionary* fee_paying_account, NSDictionary* target_account);

@interface VCProposalAuthorizeEdit : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithProposal:(id)proposal isRemove:(BOOL)isRemove dataArray:(NSArray*)dataArray callback:(BtsppApproveCallback)callback;

@end
