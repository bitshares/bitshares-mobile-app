//
//  BinSerializer.m
//
//  Created by SYALON on 13-9-3.
//
//

#import "BinSerializer.h"
#import "ChainObjectManager.h"
#import "GraphenePublicKey.h"
#include "varint.h"
#include "bts_wallet_core.h"

/**
 *  varint编码的时候临时用到的缓冲区
 */
static char _varint_tmpbuf[10];

@interface BinSerializer()
{
    NSMutableData*  _data;
    NSRange         _range;
}
@end

@implementation BinSerializer

- (id)initForReader:(NSData*)data
{
    self = [super init];
    if (self)
    {
        //  TODO:6.0 没必要copy
        _data = [data mutableCopy];
        _range = NSMakeRange(0, 0);
    }
    return self;
}

- (id)initForWriter
{
    self = [super init];
    if (self)
    {
        _data = [NSMutableData data];
        _range = NSMakeRange(0, 0);
    }
    return self;
}

- (uint8_t)read_u8
{
    uint8_t value;
    _range.length = sizeof(value);
    [_data getBytes:&value range:_range];
    _range.location += _range.length;
    return value;
}

- (uint16_t)read_u16
{
    uint16_t value;
    _range.length = sizeof(value);
    [_data getBytes:&value range:_range];
    _range.location += _range.length;
    return value;
}

- (uint32_t)read_u32
{
    uint32_t value;
    _range.length = sizeof(value);
    [_data getBytes:&value range:_range];
    _range.location += _range.length;
    return value;
}

- (uint64_t)read_u64
{
    uint64_t value;
    _range.length = sizeof(value);
    [_data getBytes:&value range:_range];
    _range.location += _range.length;
    return value;
}

- (int64_t)read_s64
{
    int64_t value;
    _range.length = sizeof(value);
    [_data getBytes:&value range:_range];
    _range.location += _range.length;
    return value;
}

- (uint32_t)read_varint32
{
    char* all_bytes = (char*)[_data bytes];
    
    //  读取
    char* buf = (char*)&all_bytes[_range.location];
    int len = (int)([_data length] - _range.location);
    unsigned char size = 0;
    unsigned long long value = varint_decode(buf, len, &size);
    
    //  递增
    _range.location += (NSUInteger)size;
    
    //  返回
    return (uint32_t)value;
}

- (NSString*)read_object_id:(EBitsharesObjectType)object_type
{
    uint32_t value = [self read_varint32];
    return [NSString stringWithFormat:@"1.%@.%@", @(object_type), @(value)];
}

- (NSData*)read_bytes:(uint32_t)size
{
    if (size == 0){
        size = [self read_varint32];
    }
    if (size > 0){
        _range.length = size;
        id d = [_data subdataWithRange:_range];
        _range.location += _range.length;
        return d;
    } else {
        return [NSData data];
    }
}

- (NSString*)read_string
{
    return [[NSString alloc] initWithData:[self read_bytes:0] encoding:NSUTF8StringEncoding];
}

- (NSString*)read_public_key
{
    secp256k1_pubkey_compressed pubkey = {0, };
    
    _range.length = sizeof(pubkey.data);
    [_data getBytes:pubkey.data range:_range];
    _range.location += _range.length;
    
    return [[[GraphenePublicKey alloc] initWithSecp256k1PublicKey:&pubkey] toWifString];
}

- (BinSerializer*)write_u8:(uint8_t)value
{
    [_data appendBytes:&value length:sizeof(value)];
    return self;
}

- (BinSerializer*)write_u16:(uint16_t)value
{
    [_data appendBytes:&value length:sizeof(value)];
    return self;
}

- (BinSerializer*)write_u32:(uint32_t)value
{
    [_data appendBytes:&value length:sizeof(value)];
    return self;
}

- (BinSerializer*)write_u64:(uint64_t)value
{
    [_data appendBytes:&value length:sizeof(value)];
    return self;
}

- (BinSerializer*)write_s64:(int64_t)value
{
    [_data appendBytes:&value length:sizeof(value)];
    return self;
}

- (BinSerializer*)write_varint32:(uint64_t)value
{
    unsigned char size = 0;
    char* buf = varint_encode((unsigned long long)value, _varint_tmpbuf, sizeof(_varint_tmpbuf), &size);
    [_data appendBytes:buf length:(NSUInteger)size];
    return self;
}

/**
 *  写入对象ID类型（格式：x.x.x）
 */
- (BinSerializer*)write_object_id:(NSString*)x_x_x object_type:(EBitsharesObjectType)object_type
{
    //  convert 1.x.n into just n
    NSString* object_id_regular = @"^[0-9]+.[0-9]+.[0-9]+$";
    NSPredicate* object_id_pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", object_id_regular];
    if ([object_id_pre evaluateWithObject:x_x_x])
    {
        //  TODO:integerValue是否溢出
        id ary = [x_x_x componentsSeparatedByString:@"."];
        NSAssert([[ary objectAtIndex:1] integerValue] == object_type, @"Invalid object id.");
        id object_id = [ary objectAtIndex:2];
        [self write_varint32:(uint64_t)[object_id integerValue]];
    }else{
        //  TODO:格式不匹配应该属于异常了
        [self write_varint32:(uint64_t)[x_x_x integerValue]];   //  TODO:integerValue是否益处
    }
    
    return self;
}

/**
 *  写入公钥对象。REMARK：BTS开头的地址。
 */
- (BinSerializer*)write_public_key:(NSString*)public_key_address
{
    secp256k1_pubkey_compressed pubkey = {0, };
    bool ret = __bts_gen_public_key_from_b58address((const unsigned char*)[public_key_address UTF8String], (const size_t)[public_key_address length],
                                                    [[ChainObjectManager sharedChainObjectManager].grapheneAddressPrefix length], &pubkey);
    if (!ret){
        //  TODO:无效公钥地址，不写入。
        return self;
    }
    
    //  写入33字节压缩公钥
    [_data appendBytes:pubkey.data length:sizeof(pubkey.data)];
    
    return self;
}

- (BinSerializer*)write_string:(NSString*)str
{
    [self write_bytes:[str dataUsingEncoding:NSUTF8StringEncoding] with_size:YES];
    return self;
}

- (BinSerializer*)write_fix_string:(NSString*)str
{
    [_data appendBytes:[str UTF8String] length:str.length];
    return self;
}

- (BinSerializer*)write_bytes:(NSData*)data with_size:(BOOL)with_size
{
    NSUInteger size = data.length;
    if (with_size){
        [self write_varint32:(uint64_t)size];
    }
    if (size > 0){
        [_data appendData:data];
    }
    return self;
}

- (NSData*)getData
{
    return [_data copy];
}

@end

