//
//  VCCallOrderRanking.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import "VCBase.h"

@interface VCRankingList : VCBase<UITableViewDelegate, UITableViewDataSource>

- (id)initWithOwner:(VCBase*)owner asset:(NSDictionary*)asset;

@property (nonatomic, strong) NSDictionary* current_asset;

@end

