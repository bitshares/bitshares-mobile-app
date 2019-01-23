//
//  TransactionBuilder.h
//  UIDemo
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>
#import "types.h"
#import "WsPromise.h"
#import "bts_chain_config.h"

/**
 *  Promise 核心对象。
 */
@interface TransactionBuilder : NSObject

- (id)init;

- (NSString*)transaction_id;

- (void)addSignKey:(NSString*)pubKey;
- (void)addSignKeys:(NSArray*)pubKeyList;
- (void)add_operation:(EBitsharesOperations)opcode opdata:(id)opdata;

- (WsPromise*)set_required_fees:(NSString*)asset_id removeDuplicates:(BOOL)removeDuplicates;
- (WsPromise*)finalize;
- (WsPromise*)broadcast;

@end
