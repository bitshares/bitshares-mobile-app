//
//  GatewayAssetItemData.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "GatewayAssetItemData.h"
#import "OrgUtils.h"

@interface GatewayAssetItemData()
{
}

@end

@implementation GatewayAssetItemData

@synthesize enableDeposit, enableWithdraw;
@synthesize symbol, backSymbol, name;

@synthesize intermediateAccount, balance;

@synthesize depositMinAmount, withdrawMinAmount, withdrawGateFee;
@synthesize supportMemo;
@synthesize confirm_block_number;
@synthesize coinType, backingCoinType;
@synthesize depositMaxAmountOnce, depositMaxAmount24Hours, withdrawMaxAmountOnce, withdrawMaxAmount24Hours;

@synthesize gdex_backingCoinItem;
@synthesize open_withdraw_item, open_deposit_item;

- (void)dealloc
{
}

@end
