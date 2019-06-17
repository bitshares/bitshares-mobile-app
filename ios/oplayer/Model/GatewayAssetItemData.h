//
//  GatewayAssetItemData.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <Foundation/Foundation.h>

@interface GatewayAssetItemData : NSObject

@property (nonatomic, assign) BOOL enableDeposit;
@property (nonatomic, assign) BOOL enableWithdraw;

@property (nonnull, nonatomic, copy) NSString* symbol;
@property (nonnull, nonatomic, copy) NSString* backSymbol;
@property (nonnull, nonatomic, copy) NSString* name;

@property (nullable, nonatomic, copy) NSString* intermediateAccount;
@property (nonnull, nonatomic, strong) NSDictionary* balance;


@property (nullable, nonatomic, copy) NSString* depositMinAmount;
@property (nullable, nonatomic, copy) NSString* withdrawMinAmount;
@property (nullable, nonatomic, copy) NSString* withdrawGateFee;

@property (nonatomic, assign) BOOL supportMemo;
@property (nullable, nonatomic, copy) NSString* confirm_block_number;

@property (nonnull, nonatomic, copy) NSString* coinType;
@property (nonnull, nonatomic, copy) NSString* backingCoinType;

@property (nullable, nonatomic, copy) NSString* depositMaxAmountOnce;
@property (nullable, nonatomic, copy) NSString* depositMaxAmount24Hours;
@property (nullable, nonatomic, copy) NSString* withdrawMaxAmountOnce;
@property (nullable, nonatomic, copy) NSString* withdrawMaxAmount24Hours;

@property (nullable, nonatomic, strong) NSDictionary* gdex_backingCoinItem;

@property (nullable, nonatomic, strong) NSDictionary* open_withdraw_item;
@property (nullable, nonatomic, strong) NSDictionary* open_deposit_item;

@end
