//
//  VCAssetOpStakeVote.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  锁仓投票

#import "VCBase.h"
#import "ViewTextFieldAmountCell.h"

@interface VCAssetOpStakeVote : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, ViewTextFieldAmountCellDelegate>

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
         result_promise:(WsPromiseObject*)result_promise;

+ (NSString*)getTicketTypeDesc:(NSInteger)ticket_type;

@end
