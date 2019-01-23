//
//  12306crypt.h
//  oplayer
//
//  Created by Aonichan on 16/1/15.
//
//

#ifndef __12306crypt_h__
#define __12306crypt_h__

#ifdef __cplusplus
extern "C"
{
#endif  //  __cplusplus
    
#include <stdio.h>

extern unsigned char table_encode_01_n_00300ae6[];
extern unsigned char table_encode_02_n_002a6ae6[];
extern unsigned char table_encode_03_n_00337ae6[];

extern unsigned char table_encode_01_s_002caae6[];
extern unsigned char table_encode_02_s_00282ae6[];
extern unsigned char table_encode_03_s_00336ae6[];

extern unsigned char table_decode_01_n_003b6ae6[];
extern unsigned char table_decode_02_n_0035cae6[];
extern unsigned char table_decode_03_n_003edae6[];

extern unsigned char table_decode_01_s_00380ae6[];
extern unsigned char table_decode_02_s_00338ae6[];
extern unsigned char table_decode_03_s_003ecae6[];
    
//  12306 mobile api: encrypt message
extern char* fencrypt(const char* plaintext, int len, int typeS);

//  12306 mobile api: decrypt message
extern char* fdecrypt(const char* cihpertext, int cihpertext_len);
    
//  12306 mobile api: calc realm value for worklight
extern char* frealm(const char* str, const char* key1, const char* key2);
    
//  aux: free memory
extern void ffree(void* ptr);

#ifdef __cplusplus
}
#endif  //  __cplusplus

#endif /* __12306crypt_h__ */
