//
//  ViewVotingCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewVotingCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "SettingManager.h"

#import "Extension.h"
#import "ChainObjectManager.h"

#import "VCVote.h"

@interface ViewVotingCell()
{
    NSDictionary*   _old_options_json;
    NSDictionary*   _new_options_json;
    
    NSMutableArray* _lbLineLabelArray;
    UIView*         _pBottomLine;
}

@end

@implementation ViewVotingCell

@synthesize xOffset;

/**
 *  计算行显示信息
 */
+ (NSMutableDictionary*)calcLineInfos:(id)old_options_json new:(id)new_options_json
{
    NSMutableDictionary* total_keys = [NSMutableDictionary dictionary];
    
    id old_voting_account = [old_options_json objectForKey:@"voting_account"];
    id new_voting_account = [new_options_json objectForKey:@"voting_account"];
    assert(old_voting_account && new_voting_account);
    BOOL old_is_self = [old_voting_account isEqualToString:BTS_GRAPHENE_PROXY_TO_SELF];
    BOOL new_is_self = [new_voting_account isEqualToString:BTS_GRAPHENE_PROXY_TO_SELF];
    
    if (old_is_self && new_is_self){
        //  1、更新前后都无代理：更新投票信息对比投票差异
        NSMutableDictionary* old_vote_ids = [NSMutableDictionary dictionary];
        NSMutableDictionary* new_vote_ids = [NSMutableDictionary dictionary];
        for (id vote_id in [old_options_json objectForKey:@"votes"]) {
            [old_vote_ids setObject:@YES forKey:vote_id];
        }
        for (id vote_id in [new_options_json objectForKey:@"votes"]) {
            [new_vote_ids setObject:@YES forKey:vote_id];
        }
        for (id vote_id in new_vote_ids) {
            if (![[old_vote_ids objectForKey:vote_id] boolValue]){
                //  新增
                [total_keys setObject:@{@"isvote":@YES, @"isadd":@YES} forKey:vote_id];
            }
        }
        for (id vote_id in old_vote_ids) {
            if (![[new_vote_ids objectForKey:vote_id] boolValue]){
                //  删除
                [total_keys setObject:@{@"isvote":@YES, @"isadd":@NO} forKey:vote_id];
            }
        }
    }else if (!old_is_self && new_is_self){
        //  2、取消代理：所有的投票都属于新增。
        [total_keys setObject:@{@"isremoveproxy":@YES, @"voting_account":old_voting_account} forKey:@"kRemoveProxy"];
        for (id vote_id in [new_options_json objectForKey:@"votes"]) {
            [total_keys setObject:@{@"isvote":@YES, @"isadd":@YES} forKey:vote_id];
        }
    }else if (old_is_self && !new_is_self){
        //  3、新增代理：投票信息根据代理人而定（自己的不显示）
        [total_keys setObject:@{@"isaddproxy":@YES, @"voting_account":new_voting_account} forKey:@"kAddProxy"];
    }else if (!old_is_self && !new_is_self){
        //  4、更新代理
        if (![old_voting_account isEqualToString:new_voting_account]){
            [total_keys setObject:@{@"isremoveproxy":@YES, @"voting_account":old_voting_account} forKey:@"kRemoveProxy"];
            [total_keys setObject:@{@"isaddproxy":@YES, @"voting_account":new_voting_account} forKey:@"kAddProxy"];
        }
    }
    
    return total_keys;
}

+ (CGFloat)calcViewHeight:(id)old_options_json new:(id)new_options_json
{
    NSDictionary* total_keys = [self calcLineInfos:old_options_json new:new_options_json];
    //  投票信息无变化
    if ([total_keys count] <= 0){
        return 0;
    }
    //  N * line_height + space_height
    return ([total_keys count] + 1) * 22 + 8;
}

- (void)dealloc
{
    [_lbLineLabelArray removeAllObjects];
    _lbLineLabelArray = nil;
    _pBottomLine = nil;
}

- (UILabel*)genOneLineLabel:(NSString*)str align:(NSTextAlignment)align
{
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.numberOfLines = 1;
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:13];
//    label.font = [UIFont fontWithName:@"Helvetica-Bold" size:13.0f];
    label.textAlignment = align;
    label.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    [self addSubview:label];
    if (str){
        label.text = str;
    }
    return label;
}

- (NSDictionary*)genLineLables:(NSString*)name status:(NSString*)status status_color:(UIColor*)status_color
{
    UILabel* lbName = [self genOneLineLabel:name align:NSTextAlignmentLeft];
    UILabel* lbResult = [self genOneLineLabel:status align:NSTextAlignmentRight];
    if (status_color){
        lbResult.textColor = status_color;
    }
    return @{@"name":lbName, @"result":lbResult};
}

/**
 *  (private) 优先按照vote_type升序排列，vote_type相同则按照vote_id升序排列。
 */
- (NSArray*)_sort_votes:(NSArray*)votes
{
    return [votes sortedArrayUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        id ary1 = [obj1 componentsSeparatedByString:@":"];
        id ary2 = [obj2 componentsSeparatedByString:@":"];
        NSInteger vote_type_1 = [[ary1 firstObject] integerValue];
        NSInteger vote_type_2 = [[ary2 firstObject] integerValue];
        if (vote_type_1 == vote_type_2){
            NSInteger vote_id_1 = [[ary1 lastObject] integerValue];
            NSInteger vote_id_2 = [[ary2 lastObject] integerValue];
            if (vote_id_1 < vote_id_2){
                return NSOrderedAscending;
            }else if (vote_id_1 > vote_id_2){
                return NSOrderedDescending;
            }else{
                return NSOrderedSame;
            }
        }else{
            if (vote_type_1 < vote_type_2){
                return NSOrderedAscending;
            }else{
                return NSOrderedDescending;
            }
        }
    })];
}

- (void)genLablesFromLineInfo:(id)line vote_id:(NSString*)vote_id
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    NSString* name;
    NSString* status;
    UIColor* status_color = nil;
    if ([[line objectForKey:@"isvote"] boolValue]){
        assert(vote_id);
        id vote_info = [chainMgr getVoteInfoByVoteID:vote_id];
        id committee_member_account = [vote_info objectForKey:@"committee_member_account"];
        if (committee_member_account){
            name = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kOpDetailSubPrefixCommittee", @"理事会"),
                    [[chainMgr getChainObjectByID:committee_member_account] objectForKey:@"name"]];
        }else{
            id witness_account = [vote_info objectForKey:@"witness_account"];
            if (witness_account){
                name = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kOpDetailSubPrefixWitness", @"见证人"),
                        [[chainMgr getChainObjectByID:witness_account] objectForKey:@"name"]];
            }else{
                name = [NSString stringWithFormat:@"%@ %@", vote_info[@"id"], vote_info[@"name"]];
            }
        }
        name = [NSString stringWithFormat:@"* %@", name];
        if ([[line objectForKey:@"isadd"] boolValue]){
            status = NSLocalizedString(@"kOpDetailSubOpAdd", @"添加");
            status_color = [ThemeManager sharedThemeManager].buyColor;
        }else{
            status = NSLocalizedString(@"kOpDetailSubOpDelete", @"删除");
            status_color = [ThemeManager sharedThemeManager].sellColor;
        }
    }else{
        if ([[line objectForKey:@"isremoveproxy"] boolValue]){
            name = [NSString stringWithFormat:@"* %@ %@", NSLocalizedString(@"kOpDetailSubPrefixProxy", @"代理人"),
                    [[chainMgr getChainObjectByID:[line objectForKey:@"voting_account"]] objectForKey:@"name"]];
            status = NSLocalizedString(@"kOpDetailSubOpDelete", @"删除");
            status_color = [ThemeManager sharedThemeManager].sellColor;
        }else{
            name = [NSString stringWithFormat:@"* %@ %@", NSLocalizedString(@"kOpDetailSubPrefixProxy", @"代理人"),
                    [[chainMgr getChainObjectByID:[line objectForKey:@"voting_account"]] objectForKey:@"name"]];
            status = NSLocalizedString(@"kOpDetailSubOpAdd", @"添加");
            status_color = [ThemeManager sharedThemeManager].buyColor;
        }
    }
    
    [_lbLineLabelArray addObject:[self genLineLables:name status:status status_color:status_color]];
}

- (id)initWithOptions:(id)old_options_json new:(id)new_options_json
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        // Initialization code
        self.xOffset = 0;
        
        _old_options_json = old_options_json;
        _new_options_json = new_options_json;
        assert(_old_options_json && _new_options_json);
        
        _lbLineLabelArray = [NSMutableArray array];
        
        NSMutableDictionary* lines = [[self class] calcLineInfos:old_options_json new:new_options_json];
        
        UILabel* name = [self genOneLineLabel:NSLocalizedString(@"kOpDetailSubTitleVoteTargeter", @"投票对象") align:NSTextAlignmentLeft];
        UILabel* result = [self genOneLineLabel:NSLocalizedString(@"kOpDetailSubTitleOperate", @"操作") align:NSTextAlignmentRight];
        name.textColor = [ThemeManager sharedThemeManager].textColorGray;
        result.textColor = [ThemeManager sharedThemeManager].textColorGray;
        [_lbLineLabelArray addObject:@{@"name":name, @"result":result}];

        id removeProxy = [lines objectForKey:@"kRemoveProxy"];
        if (removeProxy){
            [lines removeObjectForKey:@"kRemoveProxy"];
            [self genLablesFromLineInfo:removeProxy vote_id:nil];
        }
        id addProxy = [lines objectForKey:@"kAddProxy"];
        if (addProxy){
            [lines removeObjectForKey:@"kAddProxy"];
            [self genLablesFromLineInfo:addProxy vote_id:nil];
        }
        for (id vote_id in [self _sort_votes:[lines allKeys]]) {
            [self genLablesFromLineInfo:[lines objectForKey:vote_id] vote_id:vote_id];
        }
        
        _pBottomLine = [[UIView alloc] init];
        _pBottomLine.backgroundColor = [ThemeManager sharedThemeManager].bottomLineColor;
        [self addSubview:_pBottomLine];
    }
    return self;
}

- (CGFloat)getViewHeight
{
    //  N * line_height + space_height
    return [_lbLineLabelArray count] * 22 + 8;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat w = self.bounds.size.width - self.xOffset * 2;
    CGFloat fLineHeight = 22;
    [_lbLineLabelArray ruby_each_with_index:(^(id line, NSInteger idx) {
        UILabel* name = [line objectForKey:@"name"];
        UILabel* result = [line objectForKey:@"result"];
        name.frame = CGRectMake(self.xOffset, idx * fLineHeight, w * 0.8, fLineHeight);
        result.frame = CGRectMake(self.xOffset + w * 0.8, idx * fLineHeight, 0.2 * w, fLineHeight);
    })];
    
    _pBottomLine.frame = CGRectMake(self.xOffset, self.bounds.size.height - 1.0f, self.bounds.size.width - self.xOffset, 0.5);
}

@end
