//
//  BinSerializer.h
//  BTS交易签名之前的2进制流序列化
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>
#import "bts_chain_config.h"

@interface BinSerializer : NSObject

- (id)initForReader:(NSData*)data;
- (id)initForWriter;

- (uint8_t)read_u8;
- (uint16_t)read_u16;
- (uint32_t)read_u32;
- (uint64_t)read_u64;
- (int64_t)read_s64;
- (uint32_t)read_varint32;
- (NSString*)read_object_id:(EBitsharesObjectType)object_type;
- (NSData*)read_bytes:(uint32_t)size;
- (NSString*)read_string;
- (NSString*)read_public_key;

- (BinSerializer*)write_u8:(uint8_t)value;
- (BinSerializer*)write_u16:(uint16_t)value;
- (BinSerializer*)write_u32:(uint32_t)value;
- (BinSerializer*)write_u64:(uint64_t)value;
- (BinSerializer*)write_s64:(int64_t)value;
- (BinSerializer*)write_varint32:(uint64_t)value;
/**
 *  写入对象ID类型（格式：x.x.x）
 */
- (BinSerializer*)write_object_id:(NSString*)x_x_x object_type:(EBitsharesObjectType)object_type;
/**
 *  写入公钥对象。REMARK：BTS开头的地址。
 */
- (BinSerializer*)write_public_key:(NSString*)public_key_address;
/**
 *  写入字符串（变长，包含长度信息）
 */
- (BinSerializer*)write_string:(NSString*)str;
/**
 *  写入字符串（定长，不包含长度信息）
 */
- (BinSerializer*)write_fix_string:(NSString*)str;
/**
 *  写入2进制流
 */
- (BinSerializer*)write_bytes:(NSData*)data with_size:(BOOL)with_size;

- (NSData*)getData;

@end

