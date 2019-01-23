//
//  VCVote.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

typedef enum EVoteType
{
    evt_committee = 0,
    evt_witness,
    evt_work,
    
} EVoteType;

@interface VCVotePage : VCBase<UITableViewDelegate, UITableViewDataSource>

- (id)initWithOwner:(VCBase*)owner vote_type:(EVoteType)vote_type;

/**
 *  (public) 获取当前用户选择的投票列表。
 */
- (NSArray*)getCurrSelectVotingInfos;

/**
 *  (public) 重置用户所做的修改。
 */
- (void)resetUserModify;

/**
 *  (public) 处理数据响应
 */
- (void)onQueryDataResponsed:(id)data last_budget_object:(id)last_budget_object voting_info:(id)voting_info;

/**
 *  (public) 获取投票信息成功，刷新界面。
 */
- (void)onQueryVotingInfoResponsed:(id)voting_info;

@end

@interface VCVote : VCSlideControllerBase

@end
